import 'package:flutter/material.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/models/activity.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          '🏆 Top 10 Gäste',
          style: TextStyle(color: Colors.orangeAccent),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<List<Activity>>(
        stream: ActivityManager().streamAllActivities(),
        // 🔥 holt ALLE Aktivitäten
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data!;

          // 🔍 Gruppiere Aktivitäten nach Gast
          final Map<String, _GuestStats> guestStats = {};

          for (var a in activities) {
            final stats = guestStats.putIfAbsent(
                a.guestId, () => _GuestStats(a.guestId));
            if (a.action == 'drink') stats.totalDrinks++;
            if (a.action == 'check-in') stats.visitedPubs.add(a.pubId);
          }

          // 🔢 Sortiere nach Getränken, dann nach Kneipen
          final ranking = guestStats.entries.toList()
            ..sort((a, b) {
              if (a.value.totalDrinks != b.value.totalDrinks) {
                return b.value.totalDrinks.compareTo(a.value.totalDrinks);
              }
              return b.value.visitedPubs.length.compareTo(
                  a.value.visitedPubs.length);
            });

          if (ranking.isEmpty) {
            return const Center(
              child: Text(
                "Noch keine Aktivitäten 🍺",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          // 🏅 Top 10 anzeigen
          final top10 = ranking.take(10).toList();

          return ListView.builder(
            itemCount: top10.length,
            itemBuilder: (context, index) {
              final entry = top10[index];
              final rank = index + 1;
              final stats = entry.value;

              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: FutureBuilder<String?>(
                  future: GuestManager().getGuestById(stats.name),
                  builder: (context, guestSnapshot) {
                    final guestName = guestSnapshot.data ?? "Unbekannter Gast";

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: rank == 1
                            ? Colors.amber
                            : rank == 2
                            ? Colors.grey
                            : rank == 3
                            ? Colors.brown
                            : Colors.orangeAccent,
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: guestSnapshot.connectionState ==
                          ConnectionState.waiting
                          ? const Text(
                        "Lade...",
                        style: TextStyle(color: Colors.white70),
                      )
                          : Text(
                        guestName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '🍺 ${stats.totalDrinks} Getränke – 🏠 ${stats.visitedPubs
                            .length} Kneipen',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GuestStats {
  final String name;
  int totalDrinks = 0;
  Set<String> visitedPubs = {};

  _GuestStats(this.name);
}
