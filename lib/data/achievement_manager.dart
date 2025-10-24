import 'dart:async';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/achievements.dart';
import 'package:kneipentour/data/session_manager.dart';

class AchievementManager {
  static final AchievementManager _instance = AchievementManager._internal();
  factory AchievementManager() => _instance;
  AchievementManager._internal();

  /// Alle Achievements aus deiner bestehenden Datei
  late List<Achievement> achievements;

  /// Callback, wenn ein Achievement freigeschaltet wird (z. B. Popup anzeigen)
  void Function(Achievement achievement)? onAchievementUnlocked;


  bool _initialized = false;

  /// Initialisiert den Manager (z. B. beim App-Start oder im HomeScreen.initState)
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // 🔁 Bestehende Achievements laden
    achievements = AchievementData().all;



    print("✅ AchievementManager initialisiert (${achievements.length} Achievements geladen)");
  }

  /// Von außen aufrufbar, wenn eine relevante Aktion passiert:
  /// Beispiel:
  /// await AchievementManager().notifyAction(AchievementEventType.drink, guestId, pubId: "xyz");
  Future<void> notifyAction(AchievementEventType type, String guestId, {String? pubId}) async {
    if (!_initialized) initialize();

    print("🎯 Achievement-Event: $type (Gast: $guestId)");

    // Direkt statt Stream
    await _handleEvent(_AchievementEvent(type, guestId, pubId));
  }


  /// Wird intern aufgerufen, wenn ein Event eintrifft
  Future<void> _handleEvent(_AchievementEvent event) async {
    print("📨 _handleEvent() received: ${event.type} (${event.guestId})");
    for (final a in achievements) {
      print("📨 _handleEvent() using ${a.title}");
      if (a.trigger != event.type) continue;
      if (a.unlocked) continue;

      bool conditionMet = true;

      if (a.condition != null) {
        try {
          // 🔥 WICHTIG: async condition auswerten
          print("📨 _handleEvent() checking condition for ${a.title} (${event.guestId})");

          conditionMet = await a.condition!(event.guestId);
        } catch (e) {
          print("⚠️ Fehler bei Achievement-Condition '${a.id}': $e");
          conditionMet = false;
        }
      }

      if (conditionMet) {
        await _unlockAchievement(a, event.guestId);
      }
    }
  }

  /// Achievement freischalten und ggf. speichern oder Popup zeigen
  Future<void> _unlockAchievement(Achievement a, String guestId) async {
    if (a.unlocked) return;

    a.unlocked = true;
    print("🏆 Achievement freigeschaltet: ${a.title}");

    // 💾 Optional in Firestore speichern

    // 🔔 UI-Callback (Popup etc.)
    if (onAchievementUnlocked != null) {
      onAchievementUnlocked!(a);
    }
  }
}

/// Internes Eventmodell
class _AchievementEvent {
  final AchievementEventType type;
  final String guestId;
  final String? pubId;
  _AchievementEvent(this.type, this.guestId, this.pubId);
}
