import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/challenge.dart';

class ChallengeManager {
  static final ChallengeManager _instance = ChallengeManager._internal();
  factory ChallengeManager() => _instance;
  ChallengeManager._internal();

  final List<Challenge> _challenges = [
    Challenge(
      id: 'speed_drinker',
      title: 'Speed-Drinker 🍺',
      description: 'Trinke 3 Getränke in 30 Minuten!',
      duration: const Duration(minutes: 30),
      goal: 3,
    ),
    Challenge(
      id: 'tour_master',
      title: 'Tour-Meister 🧭',
      description: 'Besuche 5 Kneipen in 2 Stunden!',
      duration: const Duration(hours: 2),
      goal: 5,
    ),
  ];

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  List<Challenge> get all => _challenges;
  List<Challenge> get active =>
      _challenges.where((c) => c.isActive && !c.isCompleted).toList();

  void startChallenge(String id) {
    final challenge = _challenges.firstWhere((c) => c.id == id);
    challenge.start();
    _showChallengeNotification(challenge);
  }

  void _showChallengeNotification(Challenge challenge) async {
    const androidDetails = AndroidNotificationDetails(
      'challenge_channel',
      'Neue Challenge',
      channelDescription: 'Benachrichtigung bei neuen Challenges',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      42,
      '🎯 Neue Challenge gestartet!',
      '${challenge.title} – ${challenge.description}',
      details,
    );
  }

  void updateProgress(String id) {
    final challenge = _challenges.firstWhere((c) => c.id == id);
    challenge.increment();
  }
}
