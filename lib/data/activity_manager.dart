import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:kneipentour/config/location_config.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/data/challenge_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/models/pub.dart';
import '../models/activity.dart';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;



class ActivityManager {
  static final ActivityManager _instance = ActivityManager._internal();
  factory ActivityManager() => _instance;
  ActivityManager._internal();

  final _db = FirebaseFirestore.instance.collection('activities');

  Future<void> logActivity(Activity activity) async {
    print("📝 Speichere Activity: ${activity.toMap()}");
    await _db.add(activity.toMap());
    print("✅ Activity erfolgreich gespeichert");
  }


  /// Stream aller Aktivitäten eines bestimmten Gastes
  Stream<List<Activity>> streamGuestActivities(String guestId) {
    print("🚀 Starte Stream für GuestID: $guestId");

    return _db
        .where('guestId', isEqualTo: guestId)
        .orderBy('timestampBegin', descending: true)
        .snapshots()
        .map((snap) {
      print("📡 Firestore liefert ${snap.docs.length} Dokumente");
      return snap.docs
          .map((doc) => Activity.fromMap(doc.data(), doc.id))
          .toList();
    })
        .handleError((e) {
      print("❌ Stream-Fehler: $e");
    });
  }


  Stream<QuerySnapshot<Map<String, dynamic>>> getActivitiesStream() {
    return _db.snapshots();
  }

  Stream<List<Activity>> streamAllActivities() {
    return _db
        .snapshots()
        .map((snap) =>
        snap.docs.map((doc) => Activity.fromMap(doc.data(),doc.id)).toList());
  }

  /// Liste aller Aktivitäten (optional gefiltert nach Aktion)
  Future<List<Activity>> getGuestActivities(String guestId, {String? action}) async {
    Query query = _db.where('guestId', isEqualTo: guestId);
    if (action != null) query = query.where('action', isEqualTo: action);

    final snap = await query.get();
    return snap.docs.map((doc) {
      // Hier casten wir doc.data() explizit als Map<String, dynamic>
      return Activity.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }


  /// Alle besuchten Pubs (per check-in) eines Gastes
  Future<Set<String>> getVisitedPubIds(String guestId) async {
    final checks = await getGuestActivities(guestId, action: 'check-in');
    return checks.map((a) => a.pubId).toSet();
  }

  /// Summe Getränke eines Gastes (aus 'drink'-Aktivitäten)
  Future<int> getDrinkCount(String guestId) async {
    final drinks = await getGuestActivities(guestId, action: 'drink');
    return drinks.length;
  }

  Stream<List<Activity>> streamGuestActivitiesForPub(String pubId) {
    return FirebaseFirestore.instance
        .collection('activities')
        .where('pubId', isEqualTo: pubId)
        .where('action', isEqualTo: 'check-in')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Activity.fromMap(doc.data(), doc.id))
        .toList());
  }

  Future<Activity?> getCheckInActivity(String guestId, {String? pubId}) async {
    Query query = FirebaseFirestore.instance
        .collection('activities')
        .where('guestId', isEqualTo: guestId)
        .where('action', isEqualTo: 'check-in')
        .where('timestampEnd', isNull: true);

    // ✅ Wenn pubId angegeben ist → zusätzlich danach filtern
    if (pubId != null) {
      query = query.where('pubId', isEqualTo: pubId);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return Activity.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }

    return null; // kein aktiver Check-in gefunden
  }

  Future<void> updateActivity(Activity activity) async {
    await FirebaseFirestore.instance
        .collection('activities')
        .doc(activity.id) // Die ID des vorhandenen Aktivitätsdatensatzes
        .update(activity.toMap()); // Aktualisiert die bestehenden Felder, einschließlich `timestampEnd`
  }

  Future<void> deleteActivitiesByGuest(String guestId) async {
    final snap = await _db.where('guestId', isEqualTo: guestId).get();
    for (var doc in snap.docs) {
      await doc.reference.delete();
    }
  }
  Future<Activity?> getOpenMobileUnitRequest() async {
    final snap = await _db
        .where('action', isEqualTo: 'request_mobile')
        .where('timestampEnd', isNull: null)
        .orderBy('timestampBegin', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      return Activity.fromMap(doc.data(), doc.id);
    }
    return null;
  }

  /// Stream für aktive Mobile-Unit-Anfrage
  Stream<Activity?> streamOpenMobileUnitRequest() {
    return FirebaseFirestore.instance
        .collection('activities')
        .where('action', isEqualTo: 'request_mobile')
        .where('timestampEnd', isNull: null)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return Activity.fromMap(doc.data(), doc.id);
    });
  }


  Future<void> closeMobileUnitRequest(String activityId) async {
    await _db
        .doc(activityId)
        .update({'timestampEnd': DateTime.now()});
  }




  Future<void> sendPushToMobileUnit({
    required String guestName,
  }) async {
    // 1. Token laden
    final doc = await FirebaseFirestore.instance
        .collection('mobile_unit')
        .doc('status')
        .get();

    final token = doc.data()?['fcmToken'];
    if (token == null) {
      print("⚠️ Kein Mobile-Unit-Token gespeichert -> Keine Push möglich");
      return;
    }
    if (token == null || token.trim().isEmpty) {
      print("❌ Kein gültiger FCM Token vorhanden → Push wird übersprungen");
      return;
    }
    _sendPushMessage(token: token,title:"🚨 Mobile Einheit benötigt!",body:"$guestName braucht Unterstützung!");

  }

  Future<void> sendPushToGuest({
    required String guestId,
    required String title,
    required String message,
  }) async {
    final snap = await FirebaseFirestore.instance.collection('guests').doc(guestId).get();
    final token = snap.data()?['fcmToken'];

    if (token == null) {
      print("⚠️ Gast $guestId hat keinen Token → keine Push");
      return;
    }

    await _sendPushMessage(
      token: token,
      title: title,
      body: message,
    );
  }

  Future<void> _sendPushMessage({
    required String token, required String title, required String body
  }) async {
    // 1. Token laden

    // Service Account laden
    final serviceAccount = jsonDecode(
      await rootBundle.loadString('assets/service-account.json'),
    );

    final accountCredentials =
    auth.ServiceAccountCredentials.fromJson(serviceAccount);

    final client = await auth.clientViaServiceAccount(
      accountCredentials,
      ['https://www.googleapis.com/auth/firebase.messaging'],
    );

    final projectId = serviceAccount["project_id"];

    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/$projectId/messages:send",
    );

    final payload = {
      "message": {
        "token": token,
        "data": {
          "type": "push",
          "guestName": SessionManager().guestId,
        },
        // 👉 Sobald Icon gefixt → diesen Block wieder aktivieren:

      "notification": {
        "title": title,
        "body": body
      }
      }
    };

    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print("📡 Push Antwort ${response.statusCode}: ${response.body}");

    client.close();
  }

  Future<void> broadcastPush({
    required String title,
    required String message,
  }) async {
    final snap = await FirebaseFirestore.instance.collection('guests').get();

    for (var doc in snap.docs) {
      final token = doc.data()['fcmToken'];
      if (token != null) {
        await _sendPushMessage(
          token: token,
          title: title,
          body: message,
        );
      }
    }
  }
  Future<int> getActiveCheckInsForPub(String pubId) async {
    final snap = await FirebaseFirestore.instance
        .collection('activities')
        .where('pubId', isEqualTo: pubId)
        .where('action', isEqualTo: 'check-in')
        .where('timestampEnd', isNull: true)
        .get();
    return snap.docs.length;
  }



 }

 extension ActivityCheckIn on ActivityManager {

  /// Führt Check-In OR Drink aus
  Future<bool> checkInGuest({
    required String guestId,
    required String pubId,
    required double latitude,
    required double longitude,
    bool consumeDrink = false,
  }) async {
    final pub = PubManager().allPubs.firstWhere(
          (p) => p.id == pubId,
      orElse: () => Pub(
        id: pubId,
        name: 'Kneipe',
        description: '',
        latitude: 0,
        longitude: 0,
        iconPath: '',
      ),
    );

    // 🧭 Distanz prüfen
    final distance = LocationConfig.calculateDistance(
      latitude,
      longitude,
      pub.latitude,
      pub.longitude,
    );

    if (distance > 40) {
      print("❌ Check-In abgelehnt – zu weit entfernt (${distance.round()} m)");
      return false;
    }

    // 🔄 Falls noch in anderer Kneipe eingecheckt → Auto-Checkout
    final activeCheckIn = await getCheckInActivity(guestId);
    if (activeCheckIn != null && activeCheckIn.pubId != pubId) {
      print("🔁 Auto-Checkout von ${activeCheckIn.pubId}");
      activeCheckIn.timestampEnd = DateTime.now();
      await updateActivity(activeCheckIn);

      AchievementManager().notifyAction(
        AchievementEventType.checkOut,
        guestId,
        pubId: activeCheckIn.pubId,
      );

      await ChallengeManager().evaluateProgress(guestId);
    }

    // ✅ Check-In / Drink Activity erzeugen
    final now = DateTime.now();
    final action = consumeDrink ? 'drink' : 'check-in';

    await logActivity(
      Activity(
        id: '',
        guestId: guestId,
        pubId: pubId,
        action: action,
        timestampBegin: now,
        latitude: latitude,
        longitude: longitude,
      ),
    );

    // 🔔 Notify Achievements & Challenges
    AchievementManager().notifyAction(
      consumeDrink ? AchievementEventType.drink : AchievementEventType.checkIn,
      guestId,
      pubId: pubId,
    );

    await ChallengeManager().evaluateProgress(guestId);

    // UI Status speichern
    SessionManager().currentPubId.value = pubId;

    print("🍻 Check-In erfolgreich → ${pub.name}");
    return true;
  }

  Future<void> logDrink({
    required String guestId,
    required String pubId,
    required String pubName,
    required double latitude,
    required double longitude,
    required String payment,
  }) async {
    final now = DateTime.now();

    // → Activity anlegen
    await logActivity(
      Activity(
        id: '',
        guestId: guestId,
        pubId: pubId,
        action: 'drink',
        timestampBegin: now,
        latitude: latitude,
        longitude: longitude,
      ),
    );

    // → Achievement prüfen
    AchievementManager().notifyAction(
      AchievementEventType.drink,
      guestId,
      pubId: pubId,
    );

    print("🍺 Drink geloggt für $guestId in $pubName ($payment)");
  }

  Future<void> clearAllActivities() async {
    final db = FirebaseFirestore.instance;

    final batch = db.batch();

  final snap = await db.collection('activities').get();
  for (var doc in snap.docs) {
  batch.delete(doc.reference);
  }

  await batch.commit();
  print("🔥 Alle Bewegungsdaten gelöscht.");
  }


 }
