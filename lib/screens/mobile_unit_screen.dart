import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/models/activity.dart';
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
  }

  Future<void> _loadRequest() async {
    final request = await ActivityManager().getOpenMobileUnitRequest();
    setState(() => currentRequest = request);
  }

  Future<void> _finishRequest() async {
    if (currentRequest == null) return;
    await ActivityManager().closeMobileUnitRequest(currentRequest!.id);
    setState(() => currentRequest = null);
  }

  void _toggleAvailability() {
    setState(() {
      mobileUnit.isAvailable = !mobileUnit.isAvailable;
    });
    if(mobileUnit.isAvailable){
      _finishRequest();
    }
    PubManager().updatePubStatus(mobileUnit.id, mobileUnit.isAvailable);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mobileUnit.isAvailable
              ? "🚨 Anforderung wieder aktiviert"
              : "🛑 Mobile Einheit im Einsatz blockiert",
        ),
      ),
    );
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
  @override
  Widget build(BuildContext context) {
    final LatLng? requestPosition = (currentRequest != null)
        ? LatLng(currentRequest!.latitude, currentRequest!.longitude)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text("Mobile Einheit – ${widget.user.username}"),
        backgroundColor: Colors.redAccent,
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
                          title: currentRequest!.guestId,
                          snippet: currentRequest!.guestId,
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
              mobileUnit.isAvailable
                  ? "✅ Einsatzbereit"
                  : "🚫 Im Einsatz",
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
                  await ActivityManager().closeMobileUnitRequest(currentRequest!.id);
                  setState(() => currentRequest = null);
                },
              ),
          ],
        ),
      ),
    );

}
}
