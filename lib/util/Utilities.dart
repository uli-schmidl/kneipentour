import 'dart:ui' as ui;
import 'package:flutter/material.dart'; // ← WICHTIG wegen Colors & TextStyle
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Utilities {
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
