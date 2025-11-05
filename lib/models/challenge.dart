// lib/models/challenge.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum EligibleType {
  allGuests,
  checkedInGuests,
  inSpecificPub,
  minDrinks,
  hasAchievement,
  notCheckedInGuest,

}

class Challenge {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final DateTime startTime;
  final double? targetLatitude;
  final double? targetLongitude;
  final double? radiusMeters;

  /// Dauer in Minuten (wird im UI als Restzeit angezeigt)
  final int durationMinutes;

  /// Aktiv-Flag aus Firestore
  final bool isActive;

  /// Zielgruppe / Teilnahme-Voraussetzung
  final EligibleType eligibleType;

  /// Optional je nach Condition-Type
  final String? targetPubId;            // für inSpecificPub
  final int? minDrinks;                 // für minDrinks
  final String? requiredAchievementId;  // für hasAchievement

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.startTime,
    required this.durationMinutes,
    required this.isActive,
    required this.eligibleType,
    this.targetPubId,
    this.minDrinks,
    this.requiredAchievementId,
    this.targetLatitude,
    this.targetLongitude,
    this.radiusMeters
  });

  /// Abgeleitete Helfer
  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));
  bool get isExpired => DateTime.now().isAfter(endTime);
  Duration get remaining {
    final d = endTime.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Firestore Mapping
  factory Challenge.fromMap(Map<String, dynamic> map, String id) {
    final ts = map['startTime'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.tryParse('${map['startTime']}') ?? DateTime.now();

    // Falls du in Firestore "duration" statt "durationMinutes" gespeichert hast,
    // wird das hier elegant abgefangen.
    final int duration = (map['durationMinutes'] ?? map['duration'] ?? 0) is int
        ? (map['durationMinutes'] ?? map['duration'] ?? 0) as int
        : int.tryParse('${map['durationMinutes'] ?? map['duration'] ?? 0}') ?? 0;

    return Challenge(
      id: id,
      title: map['title'] ?? 'Challenge',
      description: map['description'] ?? '',
      iconPath: map['iconPath'] ?? 'assets/icons/achievements/first.png',
      startTime: dt,
      durationMinutes: duration,
      isActive: (map['isActive'] ?? true) == true,
      eligibleType: _parseEligibleType(map['eligibleType']),
      targetPubId: map['targetPubId'],
      minDrinks: map['minDrinks'] is int ? map['minDrinks'] as int
          : int.tryParse('${map['minDrinks'] ?? ''}'),
      requiredAchievementId: map['requiredAchievementId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'iconPath': iconPath,
    'startTime': Timestamp.fromDate(startTime),
    'durationMinutes': durationMinutes,
    'isActive': isActive,
    'eligibleType': eligibleType.name,
    if (targetPubId != null) 'targetPubId': targetPubId,
    if (minDrinks != null) 'minDrinks': minDrinks,
    if (requiredAchievementId != null) 'requiredAchievementId': requiredAchievementId,
  };

  static EligibleType _parseEligibleType(dynamic raw) {
    final s = (raw ?? '').toString();
    switch (s) {
      case 'checkedInGuests': return EligibleType.checkedInGuests;
      case 'inSpecificPub':  return EligibleType.inSpecificPub;
      case 'minDrinks':      return EligibleType.minDrinks;
      case 'hasAchievement': return EligibleType.hasAchievement;
    case 'allGuests':
      default:               return EligibleType.allGuests;
    }
  }
}
