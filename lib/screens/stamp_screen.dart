import 'package:flutter/material.dart';
import '../models/checkin.dart';
import '../models/pub.dart';
import '../data/pub_manager.dart';
import 'pub_info_screen.dart';

typedef CheckInCallback = void Function(String guestId, String pubId, {bool consumeDrink});

class StampScreen extends StatelessWidget {
  final String guestId;
  final Map<String, List<CheckIn>> guestCheckIns;
  final CheckInCallback onCheckIn;

  const StampScreen({
    Key? key,
    required this.guestId,
    required this.guestCheckIns,
    required this.onCheckIn,
  }) : super(key: key);

  int _getTotalDrinks() {
    // Zählt nur bis zu 2 pro Kneipe für Fortschritt
    return guestCheckIns[guestId]
        ?.fold(0, (sum, c) => sum! + (c.drinksConsumed.clamp(0, 2))) ??
        0;
  }

  int _getBonusDrinks() {
    // Alles über 2 ist Bonus 🍺
    return guestCheckIns[guestId]
        ?.fold(0, (sum, c) => sum! + (c.drinksConsumed > 2 ? c.drinksConsumed - 2 : 0)) ??
        0;
  }

  int _getMaxDrinks() {
    final pubs = PubManager().allPubs.where((p) => !p.isMobileUnit).toList();
    return pubs.length * 2; // 2 Getränke pro Kneipe zählen zur Tour
  }

  @override
  Widget build(BuildContext context) {
    final pubs = PubManager().allPubs.where((p) => !p.isMobileUnit).toList();
    final totalDrinks = _getTotalDrinks();
    final bonusDrinks = _getBonusDrinks();
    final maxDrinks = _getMaxDrinks();
    final progress = maxDrinks == 0 ? 0.0 : totalDrinks / maxDrinks;

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
      body: Padding(
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
                  final checkIns = guestCheckIns[guestId] ?? [];
                  final checkIn = checkIns.firstWhere(
                        (c) => c.pubId == pub.id,
                    orElse: () => CheckIn(pubId: pub.id, guestId: guestId),
                  );

                  // Bonus-Berechnung
                  final bonus = checkIn.drinksConsumed > 2
                      ? checkIn.drinksConsumed - 2
                      : 0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PubInfoScreen(
                            pub: pub,
                            guestId: guestId,
                            guestCheckIns: guestCheckIns,
                            onCheckIn: onCheckIn,
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
                              bool filled = checkIn.drinksConsumed > index;
                              return Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 4),
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
                                ? (checkIn.drinksConsumed >= 2
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
      ),
    );
  }
}
