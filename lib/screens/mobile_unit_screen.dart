import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
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

  void _toggleAvailability() {
    setState(() {
      mobileUnit.isAvailable = !mobileUnit.isAvailable;
    });
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
  Widget build(BuildContext context) {
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
            const SizedBox(height: 40),
            Icon(Icons.local_fire_department, color: Colors.red, size: 80),
            const SizedBox(height: 20),
            Text(
              mobileUnit.isAvailable
                  ? "✅ Anforderung aktiv"
                  : "🚫 Anforderung gesperrt",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(
                mobileUnit.isAvailable ? Icons.pause_circle : Icons.play_circle,
              ),
              label: Text(
                mobileUnit.isAvailable
                    ? "Anforderung deaktivieren"
                    : "Anforderung aktivieren",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mobileUnit.isAvailable
                    ? Colors.orange
                    : Colors.green,
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
                backgroundColor: mobileUnit.isOpen
                    ? Colors.blueGrey
                    : Colors.blueAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _toggleVisibility,
            ),
          ],
        ),
      ),
    );
  }
}
