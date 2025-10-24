import 'package:flutter/material.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/models/activity.dart';
import '../data/pub_manager.dart';
import 'pub_info_screen.dart';

typedef CheckInCallback = Future<void> Function(String guestId, String pubId, {bool consumeDrink});
typedef CheckOutCallback = Future<void> Function(String guestId, String pubId);


class StampScreen extends StatefulWidget {
  final String guestId;
  final CheckInCallback onCheckIn;
  final CheckOutCallback onCheckOut;


  const StampScreen({
    super.key,
    required this.guestId,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  State<StampScreen> createState() => _StampScreenState();
}

class _StampScreenState extends State<StampScreen> {
  late final Stream<List<Activity>> _activityStream;

  @override
  void initState() {
    super.initState();
    _activityStream = ActivityManager().streamGuestActivities(widget.guestId);
  }

  @override
  Widget build(BuildContext context) {
    final pubs = PubManager().allPubs.where((p) => !p.isMobileUnit).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          "🍺 Stempelkarte",
          style: TextStyle(color: Colors.orangeAccent),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<List<Activity>>(
        stream: _activityStream, // ✅ Stream bleibt stabil
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data!;
          final checkIns = activities.where((a) => a.action == 'check-in').toList();
          final drinks = activities.where((a) => a.action == 'drink').toList();

          // Gesamtstatistik
          final totalVisitedPubs = checkIns.map((a) => a.pubId).toSet().length;
          final totalDrinks = drinks.length;
          final maxDrinks = pubs.length * 2;
          final bonusDrinks =
          totalDrinks > maxDrinks ? totalDrinks - maxDrinks : 0;
          final progress = maxDrinks == 0 ? 0.0 : totalDrinks / maxDrinks;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Fortschrittsanzeige
                Text(
                  "$totalDrinks von $maxDrinks Getränken getrunken",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[800],
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 6),
                if (bonusDrinks > 0)
                  Text(
                    "🍻 Bonus-Drinks: +$bonusDrinks",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 20),

                // Grid mit Kneipen
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: pubs.map((pub) {
                      final pubDrinks =
                          drinks.where((d) => d.pubId == pub.id).length;
                      final checkedIn =
                      checkIns.any((c) => c.pubId == pub.id);

                      final bonus =
                      pubDrinks > 2 ? pubDrinks - 2 : 0;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PubInfoScreen(
                                pub: pub,
                                guestId: widget.guestId,
                                onCheckIn: widget.onCheckIn,
                                onCheckOut: widget.onCheckOut,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: pub.isOpen
                                  ? Colors.orangeAccent
                                  : Colors.grey.shade700,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Kneipenname
                              Text(
                                pub.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: pub.isOpen
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Bierkrüge (max 2)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(2, (index) {
                                  bool filled = pubDrinks > index;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      filled
                                          ? Icons.local_drink
                                          : Icons.local_drink_outlined,
                                      color: filled
                                          ? Colors.orangeAccent
                                          : Colors.grey[700],
                                      size: 28,
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 6),

                              // Bonus-Anzeige
                              if (bonus > 0)
                                Text(
                                  "+$bonus 🍺 Bonus",
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 12,
                                  ),
                                ),

                              const SizedBox(height: 4),

                              // Status
                              Text(
                                pub.isOpen
                                    ? (checkedIn
                                    ? "✅ Brima"
                                    : "Offen")
                                    : "Geschlossen",
                                style: TextStyle(
                                  color: pub.isOpen
                                      ? Colors.grey[400]
                                      : Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}
