import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Testkarte")),
      body: const GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(48.1351, 11.5820), // München
          zoom: 12,
        ),
      ),
    );
  }
}
