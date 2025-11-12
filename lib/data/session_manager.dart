import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:kneipentour/config/location_config.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/challenge_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';


class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  String? _userId;   // z. B. für Wirte/Admins, interne Zuordnung
  String? _guestId;  // Firestore-ID des Gastes (wird bei Tourstart angelegt)
  String? _userName;

  // ==== Getter ====
  String get userId => _userId ?? '';
  String get guestId => _guestId ?? '';
  String get userName => _userName ?? '';

  bool get hasGuest => _guestId != null;
  bool get isInitialized => _userName != null;

  final ValueNotifier<String?> currentPubId = ValueNotifier<String?>(null);
  // Globale Standort-Info (wird laufend aktualisiert)
  ValueNotifier<Position?> lastKnownLocation = ValueNotifier(null);
  Timer? _autoCheckoutTimer;
  final ValueNotifier<bool> isNearPub = ValueNotifier<bool>(false);




  // ==== Setter / Initialisierung ====
  void initUser({required String id, required String name}) {
    _userId = id;
    _userName = name;
  }

  void initGuest({required String guestId}) {
    _guestId = guestId;
  }

  // ==== Reset ====
  void clear() {
    reset();
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guestId');
    await prefs.remove('guestName');
    _guestId = '';
    _userName = '';
  }

  Future<void> setRole(String role) async {
    // role = 'gast', 'wirt' oder 'admin'
    // Speichere in SharedPreferences oder Firestore, je nach Implementierung
  }



  Future<void> clearSession() async {
    _guestId = '';
    // optional: SharedPreferences oder SecureStorage leeren
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.clear();
  }

  Future<void> startLocationUpdates() async {
    print("🚀 startLocationUpdates() wurde aufgerufen");
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // ✅ Sofort initialen Standort holen
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print("📍 Initialer Standort: $initialPos");
      lastKnownLocation.value = initialPos;
    } catch (e) {
      print("⚠️ Initialer Standort nicht verfügbar: $e");
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // alle 10m
      ),
    ).listen((pos) async {
      if(_guestId==null || guestId.isEmpty) return;
      print("$_guestId: Location changed! $pos");
      lastKnownLocation.value = pos;
      final nearestPub = PubManager().getNearestPub(pos.latitude, pos.longitude);
      if (nearestPub != null) {
        final dist = LocationConfig.calculateDistance(
          pos.latitude, pos.longitude,
          nearestPub.latitude, nearestPub.longitude,
        );

        isNearPub.value = dist <= 30; // z. B. 60m Radius
      } else {
        isNearPub.value = false;
      }
      await _checkAutoCheckout(pos);
      GuestManager().updateGuestLocation(guestId: _guestId!, latitude: lastKnownLocation.value!.latitude, longitude: lastKnownLocation.value!.longitude);
      AchievementManager().notifyAction(
        AchievementEventType.locationUpdate,
        _guestId!,
      );

// 🎯 Challenges prüfen
      ChallengeManager().evaluateProgress(_guestId!);
    });
  }

  Future<void> _checkAutoCheckout(Position pos) async {
      final pubId = currentPubId.value;

      if (pubId == null) return;

      final pub = PubManager().getPubById(pubId);
      if (pub == null) return;
      print("⏳ Starte Auto-Checkout ");

      final distance = LocationConfig.calculateDistance(
        pos.latitude, pos.longitude,
        pub.latitude, pub.longitude,
      );
      print("Aktuelle Entfernung zu ${pub.name}: $distance m");

      const radius = 50; // Toleranzradius

      // ✅ Wieder im Kneipenradius → Timer abbrechen
      if (isNearPub.value) {
        if (_autoCheckoutTimer != null) {
          print("✅ Gast wieder im Radius → Auto-Checkout abgebrochen");
          _autoCheckoutTimer?.cancel();
          _autoCheckoutTimer = null;
        }
        return;
      }

      // ✅ Bereits ein Countdown aktiv → nichts tun
      if (_autoCheckoutTimer != null) return;

      print("⏳ Gast zu weit entfernt → Starte Auto-Checkout Countdown…");

      _autoCheckoutTimer = Timer(const Duration(seconds: 10), () async {

        // 🚨 Nach 30 Sekunden erneut prüfen
        final currentPos = lastKnownLocation.value;
        if (currentPos == null) return;

        final recheckDistance = LocationConfig.calculateDistance(
          currentPos.latitude, currentPos.longitude,
          pub.latitude, pub.longitude,
        );

        if (recheckDistance <= radius) {
          print("✅ Gast ist zurück → kein Auto-Checkout");
          _autoCheckoutTimer = null;
          return;
        }

        print("🚶‍♂️ Auto-Checkout wird ausgeführt (${recheckDistance.round()}m entfernt)");

        final checkInActivity = await ActivityManager().getCheckInActivity(guestId, pubId: pub.id);
        if (checkInActivity != null) {
          checkInActivity.timestampEnd = DateTime.now();
          await ActivityManager().updateActivity(checkInActivity);
        }

        currentPubId.value = null;

        // ✅ Push-Nachricht senden
        await ActivityManager().sendPushToGuest(
          guestId: guestId,
          title: "Automatisch ausgecheckt",
          message: "Du hast ${pub.name} verlassen (${distance.round()} m entfernt).",
        );

        _autoCheckoutTimer = null;
      });
  }

}
