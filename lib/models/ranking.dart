import '../models/checkin.dart';

class RankingEntry {
  final String guestId;
  final int totalDrinks;
  final int visitedPubs;
  final DateTime? lastDrinkTime;

  RankingEntry({
    required this.guestId,
    required this.totalDrinks,
    required this.visitedPubs,
    this.lastDrinkTime,
  });
}

List<RankingEntry> calculateRanking(Map<String, List<CheckIn>> guestCheckIns) {
  List<RankingEntry> ranking = [];

  guestCheckIns.forEach((guestId, checkIns) {
    int drinks = checkIns.fold(0, (sum, c) => sum + c.drinksConsumed);
    int pubsVisited = checkIns.where((c) => c.drinksConsumed > 0).length;

    // Die Zeit des letzten konsumierten Getränks
    DateTime? lastDrink = checkIns
        .where((c) => c.lastDrinkTime != null)
        .map((c) => c.lastDrinkTime!)
        .fold<DateTime?>(null, (prev, elem) => prev == null || elem.isBefore(prev) ? elem : prev);

    ranking.add(RankingEntry(
      guestId: guestId,
      totalDrinks: drinks,
      visitedPubs: pubsVisited,
      lastDrinkTime: lastDrink,
    ));
  });

  // Sortieren nach Regeln
  ranking.sort((a, b) {
    if (b.totalDrinks != a.totalDrinks) return b.totalDrinks - a.totalDrinks;
    if (b.visitedPubs != a.visitedPubs) return b.visitedPubs - a.visitedPubs;
    if (a.lastDrinkTime != null && b.lastDrinkTime != null) {
      return a.lastDrinkTime!.compareTo(b.lastDrinkTime!); // früher = höher
    }
    return 0;
  });

  return ranking.take(10).toList();
}
