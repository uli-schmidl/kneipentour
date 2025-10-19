import 'package:cloud_firestore/cloud_firestore.dart';

class Guest {
  final String id;
  final String name;
  double latitude;
  double longitude;
  DateTime lastUpdated;
  List<Visit> visits; // besuchte Kneipen
  List<Drink> drinks; // getrunkene Getränke

  Guest({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    this.visits = const [],
    this.drinks = const [],
  });

  factory Guest.fromMap(Map<String, dynamic> data, String id) {
    return Guest(
      id: id,
      name: data['name'] ?? 'Gast',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      visits: (data['visits'] as List<dynamic>? ?? [])
          .map((v) => Visit.fromMap(Map<String, dynamic>.from(v)))
          .toList(),
      drinks: (data['drinks'] as List<dynamic>? ?? [])
          .map((v) => Drink.fromMap(Map<String, dynamic>.from(v)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'visits': visits.map((v) => v.toMap()).toList(),
      'drinks': drinks.map((d) => d.toMap()).toList(),
    };
  }
}

class Visit {
  final String pubId;
  final String pubName;
  final DateTime time;

  Visit({required this.pubId, required this.pubName, required this.time});

  factory Visit.fromMap(Map<String, dynamic> data) {
    return Visit(
      pubId: data['pubId'] ?? '',
      pubName: data['pubName'] ?? '',
      time: (data['time'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'pubId': pubId,
    'pubName': pubName,
    'time': Timestamp.fromDate(time),
  };
}

class Drink {
  final String pubId;
  final String pubName;
  final DateTime time;

  Drink({required this.pubId, required this.pubName, required this.time});

  factory Drink.fromMap(Map<String, dynamic> data) {
    return Drink(
      pubId: data['pubId'] ?? '',
      pubName: data['pubName'] ?? '',
      time: (data['time'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'pubId': pubId,
    'pubName': pubName,
    'time': Timestamp.fromDate(time),
  };
}
