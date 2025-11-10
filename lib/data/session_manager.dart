import 'package:flutter/cupertino.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/data/challenge_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
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
    ).listen((pos) {
      if(_guestId==null || guestId.isEmpty) return;
      print("$_guestId: Location changed! $pos");
      lastKnownLocation.value = pos;
      GuestManager().updateGuestLocation(guestId: _guestId!, latitude: lastKnownLocation.value!.latitude, longitude: lastKnownLocation.value!.longitude);
      AchievementManager().notifyAction(
        AchievementEventType.locationUpdate,
        _guestId!,
      );

// 🎯 Challenges prüfen
      ChallengeManager().evaluateProgress(_guestId!);
    });
  }
}
