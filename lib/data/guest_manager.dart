import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guest.dart';

class GuestManager {
  static final GuestManager _instance = GuestManager._internal();
  factory GuestManager() => _instance;
  GuestManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createOrUpdateGuest(String guestId, String name) async {
    final docRef = _firestore.collection('guests').doc(guestId);

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
  }

  /// 🔹 Aktualisiert den Standort und Status des Gastes in Firestore
  Future<void> updateGuestLocation({
    required String guestId,
    required double latitude,
    required double longitude,
    String? currentPubId,
    int? drinksConsumed,
  }) async {
    await _firestore.collection('guests').doc(guestId).set({
      'guestId': guestId,
      'latitude': latitude,
      'longitude': longitude,
      'currentPubId': currentPubId,
      'drinksConsumed': drinksConsumed ?? 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 🍻 Getränk hinzufügen
  Future<void> addDrink(String guestId, String pubId, String pubName) async {
    final drink = Drink(pubId: pubId, pubName: pubName, time: DateTime.now());
    await _firestore.collection('guests').doc(guestId).update({
      'drinks': FieldValue.arrayUnion([drink.toMap()]),
    });
  }

  /// 🏠 Besuch speichern
  Future<void> addVisit(String guestId, String pubId, String pubName) async {
    final visit = Visit(pubId: pubId, pubName: pubName, time: DateTime.now());
    await _firestore.collection('guests').doc(guestId).update({
      'visits': FieldValue.arrayUnion([visit.toMap()]),
    });
  }

  /// ➕ Neuen Gast registrieren
  Future<void> addGuest(Guest guest) async {
    await _firestore.collection('guests').doc(guest.id).set(guest.toMap());
  }

  /// 🔹 Liest alle Gäste aus Firestore (für Live-Map)
  Stream<QuerySnapshot<Map<String, dynamic>>> getGuestsStream() {
    return _firestore.collection('guests').snapshots();
  }

  Future<bool> nameExists(String name) async {
    final doc = await FirebaseFirestore.instance.collection('guests').doc(name).get();
    return doc.exists;
  }

}
