import 'dart:async';
import 'package:kneipentour/models/achievement.dart'; // enthält AchievementEventType!
import 'package:kneipentour/data/achievements.dart';

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

  bool _initialized = false;

  /// Initialisierung (z. B. in HomeScreen.initState aufrufen)
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    achievements = AchievementData().all;
    print("✅ AchievementManager initialisiert (${achievements.length} Achievements geladen)");
  }

  /// Von außen aufrufbar, wenn eine Aktion passiert.
  /// Beispiel: AchievementManager().notifyAction(AchievementEventType.drink, guestId)
  Future<void> notifyAction(AchievementEventType type, String guestId, {String? pubId}) async {
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

  /// Markiert ein Achievement als freigeschaltet, speichert und löst ggf. UI-Callback aus.
  Future<void> _unlockAchievement(Achievement a, String guestId) async {
    if (a.unlocked) return;

    a.unlocked = true;
    print("🏆 Achievement freigeschaltet: ${a.title}");

    // 💾 Optional: in Firestore speichern
    // await FirebaseFirestore.instance.collection('achievements').add({...});

    // 🔔 Popup- oder UI-Callback triggern
    onAchievementUnlocked?.call(a);
  }
}

/// Internes Eventmodell (private Klasse)
class _AchievementEvent {
  final AchievementEventType type;
  final String guestId;
  final String? pubId;
  _AchievementEvent(this.type, this.guestId, this.pubId);
}
