import 'dart:async';
import 'package:kneipentour/models/achievement.dart'; // enthält AchievementEventType!
import 'package:kneipentour/data/achievements.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


/// Zentraler Manager für alle Achievements.
/// Reagiert auf Events wie Check-in, Drink etc. und prüft Bedingungen.
class AchievementManager {
  static final AchievementManager _instance = AchievementManager._internal();

  factory AchievementManager() => _instance;

  AchievementManager._internal();

  /// Alle Achievements aus achievements.dart
  List<Achievement> achievements = [];

  /// Optionaler Callback, wenn ein Achievement freigeschaltet wird (z. B. Popup)
  void Function(Achievement achievement)? onAchievementUnlocked;

  /// 🔹 Liste, um doppelte Popups zu vermeiden
  final Set<String> _unlockedAchievementIds = {};

  bool _initialized = false;

  /// Initialisierung (z. B. in HomeScreen.initState aufrufen)
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    achievements = AchievementData().all;
    print("✅ AchievementManager initialisiert (${achievements
        .length} Achievements geladen)");
  }

  /// Von außen aufrufbar, wenn eine Aktion passiert.
  /// Beispiel: AchievementManager().notifyAction(AchievementEventType.drink, guestId)
  Future<void> notifyAction(AchievementEventType type, String guestId,
      {String? pubId}) async {
    if (!_initialized) initialize();

    print("🎯 Achievement-Event: $type (Gast: $guestId, Pub: ${pubId ?? '–'})");

    await _handleEvent(_AchievementEvent(type, guestId, pubId));
  }

  /// Prüft alle passenden Achievements, wenn ein Event eingeht.
  Future<void> _handleEvent(_AchievementEvent event) async {
    print("📨 _handleEvent() → ${event.type} (${event.guestId})");

    for (final a in achievements) {
      if (a.trigger != event.type) continue;
      if (a.unlocked) continue;

      print("🧩 Prüfe Achievement: ${a.title}");

      bool conditionMet = true;

      if (a.condition != null) {
        try {
          print("🔍 Evaluating condition for '${a.id}' ...");
          conditionMet = await a.condition!(event.guestId);
          print("✅ Condition result: $conditionMet");
        } catch (e, st) {
          print("⚠️ Fehler bei Achievement '${a.id}': $e\n$st");
          conditionMet = false;
        }
      }

      if (conditionMet) {
        await _unlockAchievement(a, event.guestId);
      }
    }
  }

  Future<void> _unlockAchievement(Achievement a, String guestId) async {
    // Schon erreicht? -> abbrechen
    if (a.unlocked || _unlockedAchievementIds.contains(a.id)) return;

    a.unlocked = true;
    _unlockedAchievementIds.add(a.id);

    print("🏆 Achievement freigeschaltet: ${a.title}");

    try {
      final db = FirebaseFirestore.instance;
      final ref = db
          .collection("guests")
          .doc(guestId)
          .collection("achievements")
          .doc(a.id);

      await ref.set({
        "unlocked": true,
        "timestamp": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("☁️ Firestore-Eintrag für Achievement '${a.id}' gespeichert");
    } catch (e, st) {
      print("⚠️ Fehler beim Speichern des Achievements in Firestore: $e\n$st");
    }

    // Popup-Callback
    if (onAchievementUnlocked != null) {
      print("🚀 onAchievementUnlocked Callback ausgelöst für '${a.id}'");
      onAchievementUnlocked!(a);
    } else {
      print(
          "⚠️ Kein Achievement-Callback registriert (Popup wird nicht gezeigt)");
    }
  }

  Future<void> loadUnlockedFromFirestore(String guestId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("guests")
          .doc(guestId)
          .collection("achievements")
          .get();

      for (final doc in snap.docs) {
        final id = doc.id;
        _unlockedAchievementIds.add(id);

        final ach = achievements.firstWhere(
              (a) => a.id == id,
          orElse: () => Achievement(
            id: id,
            title: id,
            description: "",
            trigger: AchievementEventType.checkIn, iconPath: '',
          ),
        );
        ach.unlocked = true;
      }

      print("✅ ${_unlockedAchievementIds.length} Achievements aus Firestore geladen");
    } catch (e) {
      print("⚠️ Fehler beim Laden der Achievements aus Firestore: $e");
    }
  }

}

  /// Internes Eventmodell (private Klasse)
class _AchievementEvent {
  final AchievementEventType type;
  final String guestId;
  final String? pubId;
  _AchievementEvent(this.type, this.guestId, this.pubId);
}
