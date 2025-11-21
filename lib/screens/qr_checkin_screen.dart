import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/models/pending_action.dart';
import 'package:kneipentour/models/pub.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kneipentour/data/pending_action_manager.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kneipentour/config/location_config.dart';

class QrCheckinScreen extends StatelessWidget {
  const QrCheckinScreen({super.key});

  Future<void> _handleScan(BuildContext context, String rawValue) async {
    try {
      /// ✅ QR-Code parsen
      final parts = rawValue.split(";");
      if (parts.length != 3) throw Exception("Ungültiges Format");

      final pubId = parts[0];
      final pubLat = double.tryParse(parts[1]);
      final pubLon = double.tryParse(parts[2]);
      final guestId = SessionManager().guestId;

      /// ✅ Position optional
      final loc = SessionManager().lastKnownLocation.value;
      final deviceLat = loc?.latitude;
      final deviceLon = loc?.longitude;

      /// 👉 Distanz *nur prüfen, wenn Position verfügbar ist*
      if (deviceLat != null && deviceLon != null && pubLat != null && pubLon != null) {
        final distance = LocationConfig.calculateDistance(
          deviceLat, deviceLon,
          pubLat, pubLon,
        );

        if (distance > 80) {
          // ⚠️ Nur Hinweis — KEIN Blocker!
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("ℹ️ Standort weicht ab (${distance.round()} m) – trotzdem Check-in okay."),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      /// ✅ Online prüfen
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity != ConnectivityResult.none;

      if (online) {
        /// Online → direkt Check-in
        await ActivityManager().checkInGuest(
          guestId: guestId,
          pubId: pubId,
          latitude: deviceLat ?? 0,
          longitude: deviceLon ?? 0,
        );

        if (context.mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Eingecheckt in ${PubManager().getPubName(pubId)}")),
        );
      } else {
        //Kann nicht null sein
        Pub? toPub = PubManager().getPubById(pubId);
        if (toPub == null){
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Ungültiger QR-Code")),
          );
          return;
        }
    /// Offline → in Pending Queue speichern
        await PendingActionManager.add(
          PendingAction(
            type: "check-in",
            guestId: guestId,
            pubId: pubId,
            latitude: toPub.latitude,
            longitude: toPub.longitude,
            timestamp: DateTime.now(),
          ),
        );

        if (context.mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("📦 Offline gespeichert – wird später synchronisiert")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Ungültiger QR-Code")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      // Optional: Fallback solange du die Camera-Permissions noch testest
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Text(
            'QR-Scan ist auf iOS in dieser Version noch eingeschränkt.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("QR-Code Check-in")),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null) {
              _handleScan(context, value);
              controller.stop(); // Kein mehrfaches Scannen
              break;
            }
          }
        },
      ),
    );
  }
}
