import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../models/checkin.dart';

class QRScannerScreen extends StatefulWidget {
  final String guestId;
  final Map<String, List<CheckIn>> guestCheckIns;
  final Function(String pubId, String guestId) onCheckIn;

  const QRScannerScreen({super.key, 
    required this.guestId,
    required this.guestCheckIns,
    required this.onCheckIn,
  });

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    ctrl.scannedDataStream.listen((scanData) {
      String scannedPubId = scanData.code!;

      // Prüfen, ob bereits eingecheckt, sonst einchecken
      final checkIns = widget.guestCheckIns.putIfAbsent(widget.guestId, () => []);
      var pubCheckIn = checkIns.firstWhere(
              (c) => c.pubId == scannedPubId,
          orElse: () {
            final newCheckIn = CheckIn(pubId: scannedPubId, guestId: widget.guestId);
            checkIns.add(newCheckIn);
            return newCheckIn;
          });

      if (pubCheckIn.drinksConsumed < 2) {
        setState(() {
          pubCheckIn.drinksConsumed++;
          pubCheckIn.lastDrinkTime = DateTime.now();
        });

        widget.onCheckIn(scannedPubId, widget.guestId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Getränk konsumiert in Kneipe $scannedPubId!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximale Getränkezahl erreicht!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QR-Code Scanner')),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.orange,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
        ),
      ),
    );
  }
}
