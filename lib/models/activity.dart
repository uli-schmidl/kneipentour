import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  String id;
  final String guestId;
  final String pubId;
  final String action; // check-in, check-out, drink, request_mobile, etc.
  DateTime? timestampBegin;
  DateTime? timestampEnd;
  final double latitude;
  final double longitude;

  Activity({
    required this.id,
    required this.guestId,
    required this.pubId,
    required this.action,
    this.timestampBegin,
    this.timestampEnd,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'guestId': guestId,
      'pubId': pubId,
      'action': action,
      'timestampBegin': Timestamp.fromDate(timestampBegin!),
      'timestampEnd': timestampEnd != null ? Timestamp.fromDate(timestampEnd!) : null,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map, String id) {
    return Activity(
      id: id,
      guestId: map['guestId'] ?? '',
      pubId: map['pubId'] ?? '',
      action: map['action'] ?? '',
      timestampBegin: map['timestampBegin'] !=null ? (map['timestampBegin'] as Timestamp).toDate() : null,
      timestampEnd: map['timestampEnd'] !=null ? (map['timestampEnd'] as Timestamp).toDate() : null,
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }
}
