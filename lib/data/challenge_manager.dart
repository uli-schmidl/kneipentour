import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/models/challenge.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/models/guest.dart';

class ChallengeManager {
  static final ChallengeManager _instance = ChallengeManager._internal();
  factory ChallengeManager() => _instance;
  ChallengeManager._internal();

  final List<Challenge> _activeChallenges = [];
  StreamSubscription? _challengeListener;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  void startListening() {
    _challengeListener?.cancel();
    _challengeListener = FirebaseFirestore.instance
        .collection('challenges')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      _activeChallenges.clear();

      for (var doc in snapshot.docs) {
        final challenge = Challenge.fromMap(doc.data(), doc.id);

        // ⏰ Nur aktive und nicht abgelaufene Challenges behalten
        if (!challenge.isExpired) {
          _activeChallenges.add(challenge);
        }
      }

      // 🔥 Wenn eine neue Challenge aktiv wurde:
      if (snapshot.docChanges
          .any((c) => c.type == DocumentChangeType.added)) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final newChallenge = Challenge.fromMap(change.doc.data()!, change.doc.id);
            await _notifyEligibleGuests(newChallenge);
          }
        }
      }
    });
  }

  List<Challenge> get activeChallenges =>
      _activeChallenges.where((c) => !c.isExpired).toList();

  void stopListening() {
    _challengeListener?.cancel();
  }

  /// Prüft, ob der aktuelle Gast an der Challenge teilnehmen darf
  Future<bool> isEligible(Challenge c, Guest guest) async {
    final guestId = SessionManager().guestId;
    final guest = await GuestManager().getGuest(guestId);
    if (guest == null) return false;

    switch (c.conditionType) {
      case ChallengeConditionType.allGuests:
        return true;

      case ChallengeConditionType.checkedInGuests:
        return await GuestManager().isGuestCheckedIn(guestId);

      case ChallengeConditionType.inSpecificPub:
        final currentPub = await GuestManager().getCurrentPubId(guestId);
        return currentPub == c.targetPubId;

      case ChallengeConditionType.minDrinks:
        final drinks = guest.drinks;
        return drinks.length >= (c.minDrinks ?? 0);

      case ChallengeConditionType.hasAchievement:
        Achievement? ach;
        try {
          ach = AchievementManager().achievements
              .firstWhere((a) => a.id == c.requiredAchievementId);
        } catch (_) {
          ach = null;
        }
        return ach?.unlocked ?? false;
    }
  }

  /// 📢 Sendet Benachrichtigung an alle berechtigten Gäste
  Future<void> _notifyEligibleGuests(Challenge challenge) async {
    print("📣 Neue Challenge gestartet: ${challenge.title}");

    final guests = await GuestManager().getAllGuests();

    for (var guest in guests) {
      final eligible = await isEligible(challenge, guest);
      if (!eligible) continue;

      await _showNotification(guest.name, challenge.title, challenge.description);
    }
  }

  Future<void> _showNotification(
      String guestName, String title, String description) async {
    const androidDetails = AndroidNotificationDetails(
      'challenge_channel',
      'Challenges',
      channelDescription: 'Benachrichtigungen zu neuen Challenges',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      guestName.hashCode,
      '🎯 Neue Challenge gestartet!',
      '$title – $description',
      details,
    );
  }


  /// Abschluss einer Challenge (für einen Gast)
  Future<void> completeChallenge(String challengeId, String guestId) async {
    await FirebaseFirestore.instance.collection('challengeCompletions').add({
      'challengeId': challengeId,
      'guestId': guestId,
      'timestamp': Timestamp.now(),
    });
    print("🏁 Challenge abgeschlossen: $challengeId ($guestId)");
  }

  /// Abgelaufene Challenges deaktivieren (optional zyklisch aufrufen)
  Future<void> deactivateExpiredChallenges() async {
    final now = Timestamp.now();
    final expired = await FirebaseFirestore.instance
        .collection('challenges')
        .where('isActive', isEqualTo: true)
        .where('endTime', isLessThan: now)
        .get();

    for (final doc in expired.docs) {
      await doc.reference.update({'isActive': false});
      print("⏱ Challenge deaktiviert: ${doc.id}");
    }
  }

  /// Admin: Challenge aktivieren/deaktivieren
  Future<void> toggleChallenge(String id, bool activate, {int durationMinutes = 60}) async {
    final now = Timestamp.now();
    final end = activate
        ? Timestamp.fromDate(now.toDate().add(Duration(minutes: durationMinutes)))
        : null;

    await FirebaseFirestore.instance.collection('challenges').doc(id).update({
      'isActive': activate,
      'startTime': activate ? now : null,
      'endTime': end,
    });
    print("⚙️ Challenge ${activate ? 'aktiviert' : 'deaktiviert'}: $id");
  }
}
