import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationConfig {
  /// Mittelpunkt des erlaubten Bereichs
  static const LatLng centerPoint = LatLng(49.32936, 10.85143);

  /// Erlaubter Radius in Metern
  static const double allowedRadius = 600;

  /// Optional: Beschreibung, z. B. für Debug oder UI
  static const String areaName = "Seitendorf";
  static const LatLng kaerwaStodl = LatLng(49.32622, 10.84811);
  static const LatLng ffwHaus = LatLng(49.32798, 10.85236);


  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // π/180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // Meter
  }

  Future<Position?> _safeGetPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Optional: User informieren
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Fehler beim Holen der Position: $e');
      return null;
    }
  }


}
