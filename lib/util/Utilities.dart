import 'dart:ui' as ui;
import 'package:flutter/material.dart'; // ← WICHTIG wegen Colors & TextStyle
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Utilities {
  static String darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#4c4c4c"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1c1c1c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]},
  {"featureType": "poi", "elementType": "all", "stylers": [{ "visibility": "off" }]},
  {"featureType": "transit", "elementType": "all", "stylers": [{ "visibility": "off" }]}
]
''';
  static Future<BitmapDescriptor> emojiMarker(
      String emoji, {
        int size = 64,
        Color background = Colors.transparent,
      }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );



    // Emoji zeichnen
    textPainter.text = TextSpan(
      text: emoji,
      style: TextStyle(fontSize: size.toDouble()),
    );

    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }
}
