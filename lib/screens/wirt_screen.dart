import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/models/user.dart';
import '../models/pub.dart';
import '../data/pubs.dart';
import '../models/checkin.dart';

class WirtScreen extends StatefulWidget {
  final UserAccount user;
  final Function(String pubId, bool newStatus)? onStatusChanged; // 👈 Callback

  const WirtScreen({
    required this.user,
    this.onStatusChanged,
    super.key,
  });

  @override
  State<WirtScreen> createState() => _WirtScreenState();
}

class _WirtScreenState extends State<WirtScreen> {
  late Pub myPub;
  bool isOpen = true;
  final TextEditingController _descController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    myPub = pubs.firstWhere(
          (p) => p.id == widget.user.assignedPubId,
      orElse: () => Pub(
        id: "unknown",
        name: "Unbekannte Kneipe",
        description: "Fehler: Keine Zuordnung gefunden.",
        latitude: 0,
        longitude: 0,
        iconPath: "",
        capacity: 0,
        isMobileUnit: false,
      ),
    );
    isOpen = true;
    _descController.text = myPub.description;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _toggleOpenStatus() {
    setState(() {
      isOpen = !isOpen;
      myPub.isOpen = isOpen;
    });

    // Kneipenstatus global ändern
    PubManager().updatePubStatus(myPub.id, isOpen);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isOpen
              ? "🍺 ${myPub.name} ist jetzt geöffnet!"
              : "🚪 ${myPub.name} wurde geschlossen.",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  void _saveChanges() {
    setState(() {
      myPub.description = _descController.text;
      if (_selectedImage != null) {
        myPub.iconPath = _selectedImage!.path;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Änderungen gespeichert ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Wirtbereich – ${myPub.name}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statusanzeige
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Status:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Row(
                  children: [
                    Text(isOpen ? "Geöffnet" : "Geschlossen",
                        style: TextStyle(
                            color: isOpen ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold)),
                    Switch(
                      value: isOpen,
                      onChanged: (_) => _toggleOpenStatus(),
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Logo bearbeiten
            Text("Kneipenlogo:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, height: 150)
                    : Image.asset(
                  myPub.iconPath.isNotEmpty
                      ? myPub.iconPath
                      : "assets/icons/default_pub.png",
                  height: 150,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Beschreibung bearbeiten
            Text("Beschreibung:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Beschreibe deine Kneipe…",
              ),
            ),
            const SizedBox(height: 20),

            // Änderungen speichern
            Center(
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text("Speichern"),
              ),
            ),
            const SizedBox(height: 30),

            // Gäste anzeigen
            Text(
              "Aktuell eingecheckte Gäste:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildGuestList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestList() {
    // Beispiel: später echte Gastdaten per State oder Firebase
    List<CheckIn> activeGuests = []; // aktuell leer

    if (activeGuests.isEmpty) {
      return const Text("Keine Gäste eingecheckt.");
    }

    return Column(
      children: activeGuests
          .map((g) => ListTile(
        leading: const Icon(Icons.person),
        title: Text(g.guestId),
        subtitle: Text(
            "Getränke: ${g.drinksConsumed} – Zuletzt: ${g.lastDrinkTime}"),
      ))
          .toList(),
    );
  }
}
