class CheckIn {
  final String pubId;
  final String guestId;
  int drinksConsumed;
  DateTime? lastDrinkTime;

  CheckIn({
    required this.pubId,
    required this.guestId,
    this.drinksConsumed = 0,
    this.lastDrinkTime,
  });
}
