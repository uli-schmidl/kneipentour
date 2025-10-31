import 'package:flutter/material.dart';

class RankInfo {
  final String title;
  final String emoji;
  final Color color;
  final int minDrinks;

  RankInfo({
    required this.title,
    required this.emoji,
    required this.color,
    required this.minDrinks,
  });
}

class RankManager {
  static final RankManager _instance = RankManager._internal();
  factory RankManager() => _instance;
  RankManager._internal();

  final List<RankInfo> _ranks = [
    RankInfo(title: "Beginner", emoji: "🍼", color: Colors.grey, minDrinks: 0),
    RankInfo(title: "Durstlöscher", emoji: "💧", color: Colors.blueAccent, minDrinks: 3),
    RankInfo(title: "Stammgast", emoji: "🍺", color: Colors.greenAccent, minDrinks: 5),
    RankInfo(title: "Zecher", emoji: "🍻", color: Colors.orangeAccent, minDrinks: 8),
    RankInfo(title: "Bierkönig", emoji: "👑", color: Colors.amber, minDrinks: 12),
    RankInfo(title: "Kneipenlegende", emoji: "🏆", color: Colors.deepPurpleAccent, minDrinks: 15),
  ];

  /// Liefert passenden Rang zur Anzahl Drinks
  RankInfo getRankForDrinks(int drinks) {
    return _ranks.lastWhere(
          (r) => drinks >= r.minDrinks,
      orElse: () => _ranks.first,
    );
  }
}
