import 'package:flutter/material.dart';

class Challenge {
  final String id;
  final String title;
  final String description;
  final Duration duration; // z. B. 1 Stunde
  final int goal; // z. B. 5 Check-ins
  int progress; // aktueller Fortschritt
  DateTime? startTime;
  bool isCompleted = false;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.goal,
    this.progress = 0,
    this.startTime,
  });

  double get progressPercent => progress / goal;

  bool get isActive {
    if (startTime == null) return false;
    return DateTime.now().isBefore(startTime!.add(duration));
  }

  Duration get remainingTime {
    if (startTime == null) return duration;
    final remaining = startTime!.add(duration).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void increment() {
    if (!isActive) return;
    progress++;
    if (progress >= goal) {
      isCompleted = true;
    }
  }

  void start() {
    startTime = DateTime.now();
    progress = 0;
    isCompleted = false;
  }
}
