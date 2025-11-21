import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:kneipentour/config/location_config.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/challenge_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/models/pub.dart';
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
  StreamSubscription<Position>? _positionSub;


  bool get hasGuest => _guestId != null;
  bool get isInitialized => _userName != null;

  final ValueNotifier<String?> currentPubId = ValueNotifier<String?>(null);
  // Globale Standort-Info (wird laufend aktualisiert)
  ValueNotifier<Position?> lastKnownLocation = ValueNotifier(null);
  Timer? _autoCheckoutTimer;
  Timer? _idleLocationTimer;

  final ValueNotifier<bool> isNearPub = ValueNotifier<bool>(false);

// Auto-Checkin
  Pub? _nearPubCandidate;
  DateTime? _nearSince;
  bool _autoCheckinReminderSent = false;



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
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location Service disabled');
          return;
        }    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

        Position initialPos;
        try {
          initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          print('📍 Initialer Standort: $initialPos');
        } catch (e) {
          print('⚠️ Konnte Standort nicht ermitteln: $e');
          initialPos = await Geolocator.getLastKnownPosition() ?? LocationConfig.posFrom(LocationConfig.centerPoint); // Fallback
        }

        LocationSettings settings;

        if (Platform.isAndroid) {
          settings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            forceLocationManager: false, // optional
          );
        } else {
          // iOS + Web + Desktop → nutzen alle das gleiche
          settings = LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 10,
          );
        }


        _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((pos) async {
      if(_guestId==null || guestId.isEmpty) return;
      debugPrint("$_guestId: Location changed! $pos");
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


      await _checkAutoCheckin();
      GuestManager().updateGuestLocation(guestId: _guestId!, latitude: lastKnownLocation.value!.latitude, longitude: lastKnownLocation.value!.longitude);
      AchievementManager().notifyAction(
        AchievementEventType.locationUpdate,
        _guestId!,
      );

// 🎯 Challenges prüfen
      ChallengeManager().evaluateProgress(_guestId!);
    }, onError: (e, st) {
      debugPrint('Location stream error: $e');
    });
    _idleLocationTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _checkAutoCheckinIdle(),
    );
      } catch (e, st) {
        debugPrint('startLocationTracking failed: $e');
        debugPrint('$st');
      }
  }

  void stopLocationTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _checkAutoCheckinIdle() async {
    try {
      // Standort aktiv abrufen
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Falls sich Standort nicht stark geändert hat → trotzdem weiterprüfen
      lastKnownLocation.value = pos; // löst normale Listener auch aus

      // Auto-Checkin-Logik manuell triggern
      await _checkAutoCheckin();

    } catch (e) {
      debugPrint("⚠️ Idle check konnte Standort nicht holen: $e");
    }
  }



  Future<void> _checkAutoCheckout(Position pos) async {
      final pubId = currentPubId.value;

      if (pubId == null) return;

      final pub = PubManager().getPubById(pubId);
      if (pub == null) return;
      debugPrint("⏳ Starte Auto-Checkout ");

      final distance = LocationConfig.calculateDistance(
        pos.latitude, pos.longitude,
        pub.latitude, pub.longitude,
      );
      debugPrint("Aktuelle Entfernung zu ${pub.name}: $distance m");

      const radius = 50; // Toleranzradius

      // ✅ Wieder im Kneipenradius → Timer abbrechen
      if (isNearPub.value) {
        if (_autoCheckoutTimer != null) {
          debugPrint("✅ Gast wieder im Radius → Auto-Checkout abgebrochen");
          _autoCheckoutTimer?.cancel();
          _autoCheckoutTimer = null;
        }
        return;
      }

      // ✅ Bereits ein Countdown aktiv → nichts tun
      if (_autoCheckoutTimer != null) return;

      debugPrint("⏳ Gast zu weit entfernt → Starte Auto-Checkout Countdown…");

      _autoCheckoutTimer = Timer(const Duration(seconds: 10), () async {

        // 🚨 Nach 30 Sekunden erneut prüfen
        final currentPos = lastKnownLocation.value;
        if (currentPos == null) return;

        final recheckDistance = LocationConfig.calculateDistance(
          currentPos.latitude, currentPos.longitude,
          pub.latitude, pub.longitude,
        );

        if (recheckDistance <= radius) {
          debugPrint("✅ Gast ist zurück → kein Auto-Checkout");
          _autoCheckoutTimer = null;
          return;
        }

        debugPrint("🚶‍♂️ Auto-Checkout wird ausgeführt (${recheckDistance.round()}m entfernt)");

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

  Future<void> _checkAutoCheckin() async {
    final pos = lastKnownLocation.value;
    if (pos == null) return;

    // Bereits eingecheckt → Auto-Checkin Reminder deaktivieren
    if (currentPubId.value != null) {
      _nearPubCandidate = null;
      _nearSince = null;
      _autoCheckinReminderSent = false;
      return;
    }

    // Nächste Kneipe unter 20 m suchen
    final pubs = PubManager().allPubs.where((p) => p.isOpen && !p.isMobileUnit);

    Pub? closePub;
    for (final pub in pubs) {
      final dist = LocationConfig.calculateDistance(
        pos.latitude, pos.longitude, pub.latitude, pub.longitude,
      );

      if (dist <= 20) {
        closePub = pub;
        break;
      }
    }

    // Keine Kneipe nah → reset
    if (closePub == null) {
      _nearPubCandidate = null;
      _nearSince = null;
      _autoCheckinReminderSent = false;
      return;
    }

    // Wenn neue Kneipe entdeckt
    if (_nearPubCandidate?.id != closePub.id) {
      _nearPubCandidate = closePub;
      _nearSince = DateTime.now();
      _autoCheckinReminderSent = false;
      return;
    }

    // 1 Minute ununterbrochen im 20-m-Radius bleiben
    if (_nearSince != null &&
        !_autoCheckinReminderSent &&
        DateTime.now().difference(_nearSince!) > const Duration(minutes: 1)) {

      _autoCheckinReminderSent = true;

      // Push senden
      await ActivityManager().sendPushToGuest(
        guestId: guestId,
        title: "🍺 Check-in Erinnerung",
        message: "Du bist anscheinend in ${closePub.name}. Möchtest du einchecken?",
      );

      debugPrint("📨 Auto-Checkin Reminder für $guestId und Kneipe ${closePub.name} gesendet!");
    }
  }

  /// Öffnet unter iOS die App-/Standort-Einstellungen,
  /// damit der User die Berechtigung nachträglich setzen kann.
  /// Unter Android geht es in die Standort-Einstellungen.
  Future<void> AppleLocationSettings() async {
    try {
      final status = await Geolocator.checkPermission();

      // Wenn dauerhaft verweigert -> direkt in die App-Einstellungen
      if (status == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      // Versuche zuerst die Standort-Einstellungen zu öffnen
      final opened = await Geolocator.openLocationSettings();

      // Falls das auf iOS/Device nicht klappt -> Fallback App-Einstellungen
      if (!opened) {
        await Geolocator.openAppSettings();
      }
    } catch (e) {
      debugPrint('AppleLocationSettings failed: $e');
    }
  }

  Future<bool> ensureLocationPermission() async {
    // 1. Ist Location an?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false; // StartScreen zeigt dann: "Nicht im Gebiet / Standort aus"
    }

    // 2. Berechtigungen prüfen
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Dem User sagen: Bitte in Einstellungen aktivieren
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }



}
