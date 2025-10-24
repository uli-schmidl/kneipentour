class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final AchievementEventType trigger;
  final bool hidden;
  bool unlocked;

  final Future<bool> Function(String guestId)? condition;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.trigger,
    this.hidden = false,
    this.unlocked = false,
    this.condition,
  });

}
enum AchievementEventType {
  checkIn,
  drink,
  checkOut,
  requestMobileUnit,
  locationUpdate,
  time,
}
