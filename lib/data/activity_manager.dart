import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity.dart';

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

  Future<Activity?> getCheckInActivity(String guestId, String pubId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('activities')
        .where('guestId', isEqualTo: guestId)
        .where('pubId', isEqualTo: pubId)
        .where('action', isEqualTo: 'check-in')
        .where('timestampEnd', isEqualTo: null) // Sucht nach Check-ins, bei denen timestampEnd noch nicht gesetzt ist
        .get();

    if (snapshot.docs.isNotEmpty) {
      // Hole den ersten Datensatz (es wird angenommen, dass nur ein Check-in pro Gast in einem Pub existiert)
      final doc = snapshot.docs.first;
      return Activity.fromMap(doc.data(), doc.id);
    }

    return null; // Kein Check-in gefunden
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


}
