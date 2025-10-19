import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pub.dart';

class PubManager {
  static final PubManager _instance = PubManager._internal();
  factory PubManager() => _instance;
  PubManager._internal();

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

  Future<void> loadPubs() async {
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
  }

  List<Pub> get allPubs => pubsList;

  Future<void> updatePubStatus(String pubId, bool isOpen) async {
    await _firestore.collection('pubs').doc(pubId).update({'isOpen': isOpen});
    final index = pubsList.indexWhere((p) => p.id == pubId);
    if (index != -1) pubsList[index].isOpen = isOpen;
  }

  /// 🚨 Mobile Einheit verfügbar / im Einsatz
  Future<void> updateAvailability(String pubId, bool isAvailable) async {
    await _firestore.collection('pubs').doc(pubId).update({'isAvailable': isAvailable});
    final index = pubsList.indexWhere((p) => p.id == pubId);
    if (index != -1) {
      pubsList[index].isAvailable = isAvailable;
    }
  }

  /// ➕ Neue Kneipe hinzufügen
  Future<void> addPub(Pub pub) async {
    await _firestore.collection('pubs').doc(pub.id).set(pub.toMap());
  }
}
