import 'package:flutter/material.dart';
import '../models/ranking.dart';
import '../models/checkin.dart';

class RankingScreen extends StatelessWidget {
  final Map<String, List<CheckIn>> guestCheckIns;

  RankingScreen({required this.guestCheckIns});

  @override
  Widget build(BuildContext context) {
    final ranking = calculateRanking(guestCheckIns);

    return Scaffold(
      appBar: AppBar(title: Text('Top 10 Gäste')),
      body: ListView.builder(
        itemCount: ranking.length,
        itemBuilder: (context, index) {
          final entry = ranking[index];
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(entry.guestId),
            subtitle: Text(
                'Getränke: ${entry.totalDrinks}, Kneipen: ${entry.visitedPubs}'),
          );
        },
      ),
    );
  }
}
