import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kneipentour/config/location_config.dart';
import 'package:kneipentour/data/activity_manager.dart';
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
            await notifyEligibleGuests(newChallenge);
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

    switch (c.eligibleType) {
      case EligibleType.allGuests:
        return true;

      case EligibleType.checkedInGuests:
        return await GuestManager().isGuestCheckedIn(guestId);

      case EligibleType.inSpecificPub:
        final currentPub = await GuestManager().getCurrentPubId(guestId);
        return currentPub == c.targetPubId;

      case EligibleType.minDrinks:
        final drinks = guest.drinks;
        return drinks.length >= (c.minDrinks ?? 0);

      case EligibleType.hasAchievement:
        Achievement? ach;
        try {
          ach = AchievementManager().achievements
              .firstWhere((a) => a.id == c.requiredAchievementId);
        } catch (_) {
          ach = null;
        }
        return ach?.unlocked ?? false;
      case EligibleType.notCheckedInGuest:
        return await GuestManager().isGuestCheckedIn(guestId)==false;

    }
  }

  Future<void> notifyEligibleGuests(Challenge challenge) async {
    final guests = await GuestManager().getAllGuests(); // wir haben das schon
    for (final guest in guests) {
      final eligible = await isEligible(challenge, guest);
      if (eligible) {
        await ActivityManager().sendPushToGuest(
          guestId: guest.id,
          title: "🔥 Neue Challenge gestartet!",
          message: challenge.title,
        );
      }
    }
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
  Future<void> toggleChallenge(Challenge id, bool activate, {int durationMinutes = 60}) async {
    final now = Timestamp.now();
    final end = activate
        ? Timestamp.fromDate(now.toDate().add(Duration(minutes: durationMinutes)))
        : null;

    await FirebaseFirestore.instance.collection('challenges').doc(id.id).update({
      'isActive': activate,
      'startTime': activate ? now : null,
      'endTime': end,
    });
    if (activate) {
      // 🆕 Startpub pro Gast speichern
      final guests = await GuestManager().getAllGuests();
      for (final g in guests) {
        final pubId = await GuestManager().getCurrentPubId(g.id);
        if (pubId != null) {
          FirebaseFirestore.instance.collection('challengeStartPub').doc("${id}_${g.id}").set({
            'challengeId': id,
            'guestId': g.id,
            'startPubId': pubId,
          });
        }
        final eligible = await isEligible(id, g);
        if (eligible) {
          await FirebaseFirestore.instance
              .collection('challenges')
              .doc(id.id)
              .collection('participants')
              .doc(g.id)
              .set({
            'guestId': g.id,
            'joinedAt': Timestamp.now(),
          });

          print("✅ Teilnehmer gespeichert: ${g.id}");
        }
      }
    }
    print("⚙️ Challenge ${activate ? 'aktiviert' : 'deaktiviert'}: $id");

  }

  Future<bool> hasReachedLocation(String guestId, double targetLat, double targetLon, double radius) async {
    final guest = await GuestManager().getGuest(guestId);
    if (guest == null) return false;

    final dist = LocationConfig.calculateDistance(
      guest.latitude,
      guest.longitude,
      targetLat,
      targetLon,
    );

    return dist <= radius;
  }

  Future<bool> isParticipant(String challengeId, String guestId) async {
    final doc = await FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId)
        .collection('participants')
        .doc(guestId)
        .get();
    return doc.exists;
  }

  /// Wird bei Standort- oder Aktivitätsänderungen aufgerufen
  Future<void> evaluateProgress(String guestId) async {
    if (_activeChallenges.isEmpty) return;

    final guest = await GuestManager().getGuest(guestId);
    if (guest == null) return;

    for (final c in activeChallenges) {
      // ⏳ Ist Challenge noch aktiv?
      if (c.isExpired) continue;
      if(await isParticipant(c.id, guest.id)==false) continue;
      switch(c.id){
      case "photo_event":
            final reached = await hasReachedLocation(
              guestId,
              LocationConfig.ffwHaus.latitude,
              LocationConfig.ffwHaus.longitude,
              35,
            );

            if (reached) {
              await completeChallenge(c.id, guestId);
              print("📸 $guestId hat Fototermin Challenge abgeschlossen!");
            }
          break;

        case "drink_3":
        // z. B. Challenge gilt nur solange man eingecheckt ist → TODO falls benötigt
          break;

        case "pub_switch":
          final currentPub = await GuestManager().getCurrentPubId(guestId);
          if (currentPub == null) return;

          final startDoc = await FirebaseFirestore.instance
              .collection('challengeStartPub')
              .doc("${c.id}_$guestId")
              .get();

          if (!startDoc.exists) return;

          final startPubId = startDoc.data()?['startPubId'];

          // ✅ Challenge erfüllt, wenn Gast in andere Kneipe eingecheckt hat
          if (startPubId != null && currentPub != startPubId) {
            await completeChallenge(c.id, guestId);
            print("🍻 Pub-Wechsel-Challenge erfüllt von $guestId");
          }
          break;
      }
    }
  }

}
