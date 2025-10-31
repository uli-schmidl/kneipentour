import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../models/pub.dart';

class PubManager {
  static final PubManager _instance = PubManager._internal();

  factory PubManager() => _instance;

  PubManager._internal();


  /// 🌍 Globaler NavigatorKey, um außerhalb des Widget-Baums zu navigieren
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Pub> pubsList = [];

  /// 🔁 Live-Stream aller Pubs aus Firestore
  Stream<List<Pub>> watchPubs() {
    return _firestore.collection('pubs').snapshots().map((snapshot) {
      pubsList = snapshot.docs
          .map((doc) => Pub.fromMap(doc.data(), doc.id))
          .toList();
      return pubsList;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPubsStream() {
    return FirebaseFirestore.instance.collection('pubs').snapshots();
  }


  Future<void> loadPubs() async {
    try {
      final snapshot = await _firestore.collection('pubs').get();

      pubsList = snapshot.docs.map((doc) {
        final data = doc.data();
        return Pub(
          id: data['id'] ?? doc.id,
          name: data['name'] ?? 'Unbenannt',
          description: data['description'] ?? '',
          latitude: (data['latitude'] ?? 0).toDouble(),
          longitude: (data['longitude'] ?? 0).toDouble(),
          iconPath: data['iconPath'] ?? 'assets/icons/pub.png',
          isMobileUnit: data['isMobileUnit'] ?? false,
          capacity: data['capacity'] ?? 0,
          isOpen: data['isOpen'] ?? true,
          isAvailable: data['isAvailable'] ?? true,
        );
      }).toList();

      print("🍻 ${pubsList.length} Pubs erfolgreich geladen");
    } catch (e, st) {
      print("❌ Fehler beim Laden der Pubs: $e\n$st");
      pubsList = [];
    }
  }


  List<Pub> get allPubs => pubsList;

  Future<void> updatePubStatus(String pubId, bool isOpen) async {
    await _firestore.collection('pubs').doc(pubId).update({'isOpen': isOpen});
    final index = pubsList.indexWhere((p) => p.id == pubId);
    if (index != -1) pubsList[index].isOpen = isOpen;
  }


  /// 🚨 Mobile Einheit verfügbar / im Einsatz
  Future<void> updateAvailability(String pubId, bool isAvailable) async {
    await FirebaseFirestore.instance
        .collection('pubs')
        .doc(pubId)
        .update({'isAvailable': isAvailable});
  }


  /// ➕ Neue Kneipe hinzufügen
  Future<void> addPub(Pub pub) async {
    await _firestore.collection('pubs').doc(pub.id).set(pub.toMap());
  }

  Future<Pub?> getMobileUnit() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('pubs')
        .where('isMobileUnit', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();

    return Pub(
      id: doc.id,
      name: data['name'] ?? 'Mobile Einheit',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      iconPath: data['iconPath'] ?? 'assets/icons/mobile.png',
      isMobileUnit: data['isMobileUnit'] ?? true,
      capacity: data['capacity'] ?? 0,
      isOpen: data['isOpen'] ?? true,
      isAvailable: (data['isAvailable'] == null)
          ? true
          : (data['isAvailable'] as bool),
    );
  }

  /// Liefert die mobile Einheit synchron aus dem Cache (`allPubs`), falls vorhanden.
  Pub? getMobileUnitSync() {
    try {
      return allPubs.firstWhere((p) => p.isMobileUnit);
    } catch (_) {
      return null;
    }
  }

  Pub createFallbackPub(String id) {
    return Pub(
      id: id,
      name: 'Kneipe',
      description: '',
      latitude: 0,
      longitude: 0,
      iconPath: 'assets/icons/bar.png',
      isMobileUnit: false,
      capacity: 0,
    );
  }

  String getPubName(String pubId) {
    try {
      return allPubs.firstWhere((p) => p.id == pubId).name;
    } catch (_) {
      return "unbekannte Kneipe";
    }
  }


}
