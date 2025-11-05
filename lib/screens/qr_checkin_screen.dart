import 'package:flutter/material.dart';
import 'package:kneipentour/models/pending_action.dart';
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
      final pubLat = double.tryParse(parts[1]) ?? 0;
      final pubLon = double.tryParse(parts[2]) ?? 0;
      final guestId = SessionManager().guestId;

      /// ✅ Aktuelle Position abrufen
      final loc = SessionManager().lastKnownLocation.value;
      final deviceLat = loc?.latitude ?? 0;
      final deviceLon = loc?.longitude ?? 0;

      /// ✅ Distanz prüfen
      final distance = LocationConfig.calculateDistance(deviceLat, deviceLon, pubLat, pubLon);
      if (distance > 60) { // 60m Toleranz
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("📍 Du bist zu weit entfernt (${distance.round()} m)")),
        );
        return;
      }

      /// ✅ Online prüfen
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity != ConnectivityResult.none;

      if (online) {
        /// Direkter Check-in
        await ActivityManager().checkInGuest(
          guestId: guestId,
          pubId: pubId,
          latitude: deviceLat,
          longitude: deviceLon,
        );

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Erfolgreich eingecheckt!")),
        );
      } else {
        /// Offline → PendingAction speichern
        await PendingActionManager.add(
          PendingAction(
            type: "check-in",
            guestId: guestId,
            pubId: pubId,
            latitude: deviceLat,
            longitude: deviceLon,
            timestamp: DateTime.now(),
          ),
        );

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("📦 Offline gespeichert – wird synchronisiert.")),
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
