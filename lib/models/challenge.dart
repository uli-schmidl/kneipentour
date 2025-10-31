// lib/models/challenge.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeConditionType {
  allGuests,
  checkedInGuests,
  inSpecificPub,
  minDrinks,
  hasAchievement,
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final DateTime startTime;

  /// Dauer in Minuten (wird im UI als Restzeit angezeigt)
  final int durationMinutes;

  /// Aktiv-Flag aus Firestore
  final bool isActive;

  /// Zielgruppe / Teilnahme-Voraussetzung
  final ChallengeConditionType conditionType;

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
    required this.conditionType,
    this.targetPubId,
    this.minDrinks,
    this.requiredAchievementId,
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
      conditionType: _parseConditionType(map['conditionType']),
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
    'conditionType': conditionType.name,
    if (targetPubId != null) 'targetPubId': targetPubId,
    if (minDrinks != null) 'minDrinks': minDrinks,
    if (requiredAchievementId != null) 'requiredAchievementId': requiredAchievementId,
  };

  static ChallengeConditionType _parseConditionType(dynamic raw) {
    final s = (raw ?? '').toString();
    switch (s) {
      case 'checkedInGuests': return ChallengeConditionType.checkedInGuests;
      case 'inSpecificPub':  return ChallengeConditionType.inSpecificPub;
      case 'minDrinks':      return ChallengeConditionType.minDrinks;
      case 'hasAchievement': return ChallengeConditionType.hasAchievement;
      case 'allGuests':
      default:               return ChallengeConditionType.allGuests;
    }
  }
}
