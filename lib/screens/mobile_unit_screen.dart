import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/models/activity.dart';
import 'package:kneipentour/screens/start_screen.dart';
import '../models/user.dart';
import '../models/pub.dart';
import '../data/pub_manager.dart';

class MobileUnitScreen extends StatefulWidget {
  final UserAccount user;

  const MobileUnitScreen({required this.user, super.key});

  @override
  State<MobileUnitScreen> createState() => _MobileUnitScreenState();
}

class _MobileUnitScreenState extends State<MobileUnitScreen> {
  late Pub mobileUnit;
  Activity? currentRequest;


  @override
  void initState() {
    super.initState();
    _loadRequest();
    mobileUnit = PubManager().allPubs.firstWhere(
          (p) => p.isMobileUnit,
      orElse: () => Pub(
        id: 'mobile_unit',
        name: 'Mobile Einheit',
        description: 'Unterwegs im Einsatz',
        latitude: 0,
        longitude: 0,
        iconPath: 'assets/icons/mobile.png',
        isMobileUnit: true,
        isOpen: true,
      ),
    );
    _saveMobileUnitToken();
    _startListeningForRequests();

  }

  Future<void> _saveMobileUnitToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('mobile_unit')
        .doc('status')
        .set(
      {
        'fcmToken': token,
        'isOnline': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    print("✅ Mobile Unit Token gespeichert: $token");
  }

  StreamSubscription<Activity?>? _requestSub;

  void _startListeningForRequests() {
    _requestSub = ActivityManager()
        .streamOpenMobileUnitRequest()
        .listen((request) {
      setState(() {
        currentRequest = request;

        // 🔥 Wenn es eine aktive Anfrage gibt → Einheit automatisch "nicht verfügbar"
        mobileUnit.isAvailable = (request == null);

        // 💾 Im Firestore spiegeln
        PubManager().updateAvailability(mobileUnit.id, mobileUnit.isAvailable);
      });
    });
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    super.dispose();
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inSeconds < 60) return "${diff.inSeconds}s";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";

    return "${diff.inDays} d";
  }


  Future<void> _loadRequest() async {
    final request = await ActivityManager().getOpenMobileUnitRequest();
    setState(() => currentRequest = request);
  }

  Future<void> _finishRequest() async {
    if (currentRequest == null) return;

    await ActivityManager().closeMobileUnitRequest(currentRequest!.id);
    await PubManager().updateAvailability(mobileUnit.id, true);

  }


  void _toggleAvailability() async {
    setState(() {
      mobileUnit.isAvailable = !mobileUnit.isAvailable;
    });

    await PubManager().updateAvailability(mobileUnit.id, mobileUnit.isAvailable);

    if (!mobileUnit.isAvailable && currentRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📞 Noch keine Anfrage, aber Einheit blockiert.")),
      );
    }
  }


  void _toggleVisibility() {
    setState(() {
      mobileUnit.isOpen = !mobileUnit.isOpen;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mobileUnit.isOpen
              ? "👀 Mobile Einheit ist jetzt auf der Karte sichtbar"
              : "👻 Mobile Einheit ist jetzt unsichtbar",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? requestPosition = (currentRequest != null)
        ? LatLng(currentRequest!.latitude, currentRequest!.longitude)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text("Wirtbereich – Mobile Unit"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const StartScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // 🗺️ Karte anzeigen, wenn ein aktiver Request vorhanden ist
            if (requestPosition != null)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: requestPosition,
                      zoom: 17,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId("caller"),
                        position: requestPosition,
                        infoWindow: InfoWindow(
                          title: currentRequest != null ? currentRequest!.guestId : "",
                          snippet: currentRequest != null ? currentRequest!.timestampBegin.toString():"",
                        ),
                      ),
                    },
                    myLocationButtonEnabled: true,
                    myLocationEnabled: true,
                  ),
                ),
              )
            else
              const Text(
                "🚑 Keine aktiven Einsätze.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

            const SizedBox(height: 30),

            Icon(Icons.local_fire_department, color: Colors.red, size: 80),
            const SizedBox(height: 20),

            Text(
              mobileUnit.isAvailable || currentRequest==null
                  ? "✅ Einsatzbereit"
                  : "${currentRequest!.guestId} – vor ${_timeAgo(currentRequest!.timestampBegin!)}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: Icon(
                mobileUnit.isAvailable ? Icons.pause_circle : Icons.play_circle,
              ),
              label: Text(
                mobileUnit.isAvailable
                    ? "Mobile Einheit sperren"
                    : "Mobile Einheit freigeben",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                mobileUnit.isAvailable ? Colors.orange : Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _toggleAvailability,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: Icon(
                mobileUnit.isOpen ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(
                mobileUnit.isOpen
                    ? "Von Karte ausblenden"
                    : "Auf Karte anzeigen",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                mobileUnit.isOpen ? Colors.blueGrey : Colors.blueAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _toggleVisibility,
            ),

            const SizedBox(height: 20),

            // ✅ Einsatz abschließen, falls aktiv
            if (currentRequest != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text("Einsatz abgeschlossen"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  await _finishRequest();
                  setState(() => currentRequest = null);
                },
              ),
          ],
        ),
      ),
    );

}
}
