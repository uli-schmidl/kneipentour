import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guest.dart';

class GuestManager {
  static final GuestManager _instance = GuestManager._internal();
  factory GuestManager() => _instance;
  GuestManager._internal();

  final _guestsCollection = FirebaseFirestore.instance.collection('guests');

  /// 🔹 Erstellt oder aktualisiert einen Gast
  Future<void> createOrUpdateGuest(String guestId, String name) async {
    final docRef = _guestsCollection.doc(guestId);

    try {
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'guestId': guestId,
          'name': name,
          'latitude': 0.0,
          'longitude': 0.0,
          'drinksConsumed': 0,
          'currentPubId': null,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print("👤 Neuer Gast angelegt: $name ($guestId)");
      } else {
        await docRef.update({
          'name': name,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print("🔁 Gast aktualisiert: $name ($guestId)");
      }
    } catch (e) {
      print("❌ Fehler bei createOrUpdateGuest: $e");
    }
  }

  /// 📍 Aktualisiert Standort und Status des Gastes
  Future<void> updateGuestLocation({
    required String guestId,
    required double latitude,
    required double longitude,
    String? currentPubId,
    int? drinksConsumed,
  }) async {
    try {
      await _guestsCollection.doc(guestId).set({
        'latitude': latitude,
        'longitude': longitude,
        'currentPubId': currentPubId,
        'drinksConsumed': drinksConsumed ?? 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("✅ Standort aktualisiert für $guestId → $latitude, $longitude");
    } catch (e) {
      print("❌ Fehler beim Standort-Update: $e");
    }
  }

  /// 🍺 Getränk hinzufügen
  Future<void> addDrink(String guestId, String pubId, String pubName) async {
    final drink = Drink(pubId: pubId, pubName: pubName, time: DateTime.now());
    await _guestsCollection.doc(guestId).update({
      'drinks': FieldValue.arrayUnion([drink.toMap()]),
    });
  }

  /// 🏠 Besuch speichern
  Future<void> addVisit(String guestId, String pubId, String pubName) async {
    final visit = Visit(pubId: pubId, pubName: pubName, time: DateTime.now());
    await _guestsCollection.doc(guestId).update({
      'visits': FieldValue.arrayUnion([visit.toMap()]),
    });
  }

  /// 🔹 Alle Gäste-Updates live (z. B. für Karte)
  Stream<QuerySnapshot<Map<String, dynamic>>> getGuestsStream() {
    return _guestsCollection.snapshots();
  }

  /// 🔍 Prüfen, ob Name bereits vergeben ist
  Future<bool> nameExists(String name) async {
    final doc = await _guestsCollection.doc(name).get();
    return doc.exists;
  }

  /// 🧑 Gastnamen über ID abrufen
  Future<String?> getGuestById(String guestId) async {
    try {
      final doc = await _guestsCollection.doc(guestId).get();
      if (doc.exists) {
        final guest = Guest.fromMap(doc.data()!, doc.id);
        return guest.name;
      }
    } catch (e) {
      print("⚠️ Fehler beim Abrufen des Gast-Namens: $e");
    }
    return null;
  }

  Future<void> deleteGuest(String guestId) async {
    await FirebaseFirestore.instance.collection('guests').doc(guestId).delete();
  }

}
