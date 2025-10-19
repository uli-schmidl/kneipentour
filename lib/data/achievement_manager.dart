import '../models/achievement.dart';
import '../data/achievements.dart';

class AchievementManager {
  static final AchievementManager _instance = AchievementManager._internal();
  factory AchievementManager() => _instance;
  AchievementManager._internal();

  final List<Achievement> _achievements = allAchievements;

  List<Achievement> get achievements => _achievements;

  bool unlock(String id) {
    final achievement = _achievements.firstWhere((a) => a.id == id);
    if (!achievement.unlocked) {
      achievement.unlocked = true;
      return true; // neu freigeschaltet
    }
    return false; // war schon freigeschaltet
  }

  bool isUnlocked(String id) =>
      _achievements.firstWhere((a) => a.id == id).unlocked;
}
