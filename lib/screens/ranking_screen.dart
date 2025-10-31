import 'package:flutter/material.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/rank_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/session_manager.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<List<_GuestRankEntry>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _rankingFuture = _loadRankingSnapshot();
  }

  Future<List<_GuestRankEntry>> _loadRankingSnapshot() async {
    print("🚀 Starte Ranking-Ladevorgang...");
    List<_GuestRankEntry> entries = [];

    try {
      final guests = await GuestManager().getAllGuests();
      print("👥 Gäste geladen: ${guests.length}");

      if (guests.isEmpty) {
        print("⚠️ Keine Gäste gefunden");
        return [];
      }

      // Testweise nur die ersten 5 Gäste abrufen
      final limitedGuests = guests.take(5).toList();

      final futures = limitedGuests.map((guest) async {
        print("🔍 Prüfe Gast: ${guest.name}");

        try {
          final drinks = await ActivityManager()
              .getGuestActivities(guest.id, action: 'drink')
              .timeout(const Duration(seconds: 3), onTimeout: () {
            print("⏰ Timeout bei ${guest.name}");
            return [];
          });

          final count = drinks.length;
          print("🍺 ${guest.name} → $count Drinks");
          final rank = RankManager().getRankForDrinks(count);

          return _GuestRankEntry(
            guestName: guest.name,
            drinkCount: count,
            rank: rank,
          );
        } catch (e) {
          print("⚠️ Fehler bei ${guest.name}: $e");
          return _GuestRankEntry(
            guestName: guest.name,
            drinkCount: 0,
            rank: RankManager().getRankForDrinks(0),
          );
        }
      }).toList();

      entries = await Future.wait(futures);
      print("✅ Alle Gäste verarbeitet (${entries.length})");

      entries.sort((a, b) => b.drinkCount.compareTo(a.drinkCount));
    } catch (e, st) {
      print("💥 Ranking-Fehler: $e\n$st");
    }

    return entries;
  }



  /*Future<List<_GuestRankEntry>> _loadRankingSnapshot() async {
    final guests = await GuestManager().getAllGuests();

    // Wenn keine Gäste vorhanden sind
    if (guests.isEmpty) return [];

    // 🔹 Parallele Abfragen (statt nacheinander!)
    final futures = guests.map((guest) async {
      try {
        // Hole alle 'drink'-Einträge parallel
        final drinks = await ActivityManager()
            .getGuestActivities(guest.id, action: 'drink')
            .timeout(const Duration(seconds: 5), onTimeout: () => []);

        final count = drinks.length;
        final rank = RankManager().getRankForDrinks(count);

        return _GuestRankEntry(
          guestName: guest.name,
          drinkCount: count,
          rank: rank,
        );
      } catch (e) {
        print("⚠️ Fehler bei ${guest.name}: $e");
        return _GuestRankEntry(
          guestName: guest.name,
          drinkCount: 0,
          rank: RankManager().getRankForDrinks(0),
        );
      }
    }).toList();

    // 🔹 Warte auf alle Futures gleichzeitig
    final entries = await Future.wait(futures);

    // 🔹 Sortieren nach Anzahl der Drinks
    entries.sort((a, b) => b.drinkCount.compareTo(a.drinkCount));

    return entries;
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("🏆 Rangliste", style: TextStyle(color: Colors.orangeAccent)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.orangeAccent),
      ),
      body: FutureBuilder<List<_GuestRankEntry>>(
        future: _rankingFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            );
          }

          final ranking = snapshot.data!;
          if (ranking.isEmpty) {
            return const Center(
              child: Text("Noch keine Teilnehmer 🍺", style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ranking.length,
            itemBuilder: (context, index) {
              final entry = ranking[index];
              final isCurrentUser = entry.guestName == SessionManager().guestId;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.orangeAccent.withOpacity(0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrentUser
                      ? Border.all(color: Colors.orangeAccent, width: 1)
                      : null,
                ),
                child: ListTile(
                  leading: Text(
                    entry.rank.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    "${index + 1}. ${entry.guestName}",
                    style: TextStyle(
                      color: entry.rank.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "${entry.rank.title} – ${entry.drinkCount} Getränke",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// interne Hilfsklasse für Ranking-Einträge
class _GuestRankEntry {
  final String guestName;
  final int drinkCount;
  final RankInfo rank;

  _GuestRankEntry({
    required this.guestName,
    required this.drinkCount,
    required this.rank,
  });
}
