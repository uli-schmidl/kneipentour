import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationConfig {
  /// Mittelpunkt des erlaubten Bereichs
  static const LatLng centerPoint = LatLng(49.32936, 10.85143);

  /// Erlaubter Radius in Metern
  static const double allowedRadius = 600;

  /// Optional: Beschreibung, z. B. für Debug oder UI
  static const String areaName = "Seitendorf";
  static const LatLng kaerwaStodl = LatLng(49.32622, 10.84811);

}
