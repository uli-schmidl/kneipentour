class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  bool unlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    this.unlocked = false,
  });
}
