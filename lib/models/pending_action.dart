class PendingAction {
  final String type;
  final String guestId;
  final String pubId;
  final String? pubName; // nur für Drinks
  final double latitude;
  final double longitude;
  final String payment; // default: "cash"
  final DateTime timestamp;

  PendingAction({
    required this.type,
    required this.guestId,
    required this.pubId,
    required this.latitude,
    required this.longitude,
    this.pubName,
    this.payment = "cash",
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    "type": type,
    "guestId": guestId,
    "pubId": pubId,
    "pubName": pubName,
    "latitude": latitude,
    "longitude": longitude,
    "payment": payment,
    "timestamp":timestamp,
  };

  static PendingAction fromMap(Map<String, dynamic> json) => PendingAction(
    type: json["type"],
    guestId: json["guestId"],
    pubId: json["pubId"],
    pubName: json["pubName"],
    latitude: json["latitude"]?.toDouble() ?? 0.0,
    longitude: json["longitude"]?.toDouble() ?? 0.0,
    payment: json["payment"] ?? "cash",
    timestamp: json["timestamp"],
  );
}
