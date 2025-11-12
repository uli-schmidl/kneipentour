import 'package:flutter/material.dart';
import '../data/achievement_manager.dart';
import '../data/challenge_manager.dart';
import '../models/achievement.dart';
import '../models/challenge.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen>
    with SingleTickerProviderStateMixin {
  final achievements = AchievementManager().achievements;
  final challengeManager = ChallengeManager();

  @override
  Widget build(BuildContext context) {
    final visibleAchievements = achievements
        .where((a) => !a.hidden || (a.hidden && a.unlocked))
        .toList();
    final activeChallenges = challengeManager.activeChallenges;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Erfolge & Challenges',
          style: TextStyle(color: Colors.orangeAccent),
        ),
        backgroundColor: Colors.black,
        elevation: 6,
        shadowColor: Colors.orangeAccent.withOpacity(0.4),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 🏆 Achievements
          const Text(
            'Erfolge',
            style: TextStyle(
              color: Colors.orangeAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (visibleAchievements.isEmpty)
            const Text(
              'Noch keine Erfolge freigeschaltet 🎯',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            )
          else
            ...visibleAchievements.map(_buildAchievementCard),

          if (activeChallenges.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(color: Colors.orangeAccent),
            const SizedBox(height: 12),
            const Text(
              'Aktive Challenges',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...activeChallenges.map((c) => _buildChallengeCard(c)),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement a) {
    final unlocked = a.unlocked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: unlocked ? Colors.black.withOpacity(0.8) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? Colors.limeAccent : Colors.white10,
          width: unlocked ? 2.5 : 1,
        ),
        boxShadow: unlocked
            ? [
          BoxShadow(
            color: Colors.orangeAccent.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ]
            : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              colorFilter: unlocked
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                  : const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: Image.asset(a.iconPath, height: 46),
            ),
            if (unlocked)
              Positioned(
                bottom: 0,
                right: 0,
                child: Icon(Icons.check_circle,
                    color: Colors.greenAccent.shade400, size: 20),
              ),
          ],
        ),
        title: Text(
          a.title,
          style: TextStyle(
            color: unlocked ? Colors.orangeAccent : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          a.description,
          style: TextStyle(
            color: unlocked ? Colors.white70 : Colors.white38,
          ),
        ),
        trailing: unlocked
            ? const Icon(Icons.emoji_events, color: Colors.amberAccent)
            : const Icon(Icons.lock, color: Colors.grey),
      ),
    );
  }

  Widget _buildChallengeCard(Challenge c) {
    final remaining = c.remaining;
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;

    return Card(
      color: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.orangeAccent),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.title,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              c.description,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              "⏱ verbleibend: ${mins}m ${secs}s",
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
