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

class _AchievementScreenState extends State<AchievementScreen> {
  final achievements = AchievementManager().achievements;
  final challengeManager = ChallengeManager();

  @override
  Widget build(BuildContext context) {
    // 🔍 Nur sichtbare oder freigeschaltete Achievements anzeigen
    final visibleAchievements = achievements
        .where((a) => !a.hidden || (a.hidden && a.unlocked))
        .toList();
    final activeChallenges = challengeManager.active;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Erfolge & Challenges'),
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
    return Card(
      color: const Color(0xFF1E1E1E),
      child: ListTile(
        leading: ColorFiltered(
          colorFilter: a.unlocked
              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
              : const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0, // Grauformel R
            0.2126, 0.7152, 0.0722, 0, 0, // Grauformel G
            0.2126, 0.7152, 0.0722, 0, 0, // Grauformel B
            0, 0, 0, 1, 0,                 // Alpha
          ]),
          child: Image.asset(a.iconPath, height: 40),
        ),

        title: Text(
          a.title,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(a.description, style: const TextStyle(color: Colors.white70)),
        trailing: Icon(
          a.unlocked ? Icons.check_circle : Icons.lock,
          color: a.unlocked ? Colors.greenAccent : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Challenge c) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: ListTile(
        title: Text(
          c.title,
          style: const TextStyle(color: Colors.orangeAccent),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.description, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: c.progressPercent,
              color: c.isCompleted ? Colors.greenAccent : Colors.orangeAccent,
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(height: 4),
            Text(
              c.isCompleted
                  ? "✅ Abgeschlossen!"
                  : "Noch ${c.remainingTime.inMinutes} Minuten",
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
