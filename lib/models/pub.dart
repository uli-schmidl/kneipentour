import 'package:cloud_firestore/cloud_firestore.dart';

class Pub {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  String description;
  String iconPath;
  bool isMobileUnit;
  int capacity;
  bool isOpen;
  bool isAvailable;

  Pub({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.iconPath,
    this.isMobileUnit = false,
    this.capacity = 0,
    this.isOpen = true,
    this.isAvailable = true,
  });

  /// 🧩 Firestore → Pub-Objekt
  factory Pub.fromMap(Map<String, dynamic> data, String documentId) {
    return Pub(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      iconPath: data['iconPath'] ?? '',
      isMobileUnit: data['isMobileUnit'] ?? false,
      capacity: (data['capacity'] ?? 0).toInt(),
      isOpen: data['isOpen'] ?? true,
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  /// 🧠 Pub-Objekt → Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'iconPath': iconPath,
      'isMobileUnit': isMobileUnit,
      'capacity': capacity,
      'isOpen': isOpen,
      'isAvailable': isAvailable,
    };
  }
}
