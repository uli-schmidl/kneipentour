import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/models/user.dart';
import 'package:kneipentour/screens/start_screen.dart';
import '../models/pub.dart';
import '../models/checkin.dart';

class WirtScreen extends StatefulWidget {
  final UserAccount user;

  const WirtScreen({
    required this.user,
    super.key,
  });

  @override
  State<WirtScreen> createState() => _WirtScreenState();
}

class _WirtScreenState extends State<WirtScreen> {
  Pub? myPub;
  bool isOpen = true;
  bool isAvailable = true; // 👈 neu für mobile Einheit
  final TextEditingController _descController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPubData();
  }

  Future<void> _loadPubData() async {
    try {
      final pubDoc = await FirebaseFirestore.instance
          .collection('pubs')
          .doc(widget.user.assignedPubId)
          .get();

      if (pubDoc.exists) {
        final data = pubDoc.data()!;
        setState(() {
          myPub = Pub(
            id: pubDoc.id,
            name: data['name'] ?? 'Unbekannte Kneipe',
            description: data['description'] ?? '',
            latitude: (data['latitude'] ?? 0).toDouble(),
            longitude: (data['longitude'] ?? 0).toDouble(),
            iconPath: data['iconPath'] ?? '',
            isMobileUnit: data['isMobileUnit'] ?? false,
            capacity: data['capacity'] ?? 0,
            isOpen: data['isOpen'] ?? true,
            isAvailable: data['isAvailable'] ?? true, // 👈 hinzugefügt
          );
          isOpen = myPub!.isOpen;
          isAvailable = myPub!.isAvailable;
          _descController.text = myPub!.description;
          _isLoading = false;
        });

      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Kneipe nicht gefunden.")),
        );
      }
    } catch (e) {
      print("❌ Fehler beim Laden der Kneipe: $e");
      setState(() => _isLoading = false);
    }
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

  Future<void> _toggleOpenStatus() async {
    if (myPub == null) return;

    final newStatus = !isOpen;
    setState(() {
      isOpen = newStatus;
      myPub!.isOpen = newStatus;
    });

    await FirebaseFirestore.instance
        .collection('pubs')
        .doc(myPub!.id)
        .update({'isOpen': newStatus});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus
              ? "🍺 ${myPub!.name} ist jetzt geöffnet!"
              : "🚪 ${myPub!.name} wurde geschlossen.",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleAvailability() async {
    if (myPub == null) return;

    final newStatus = !isAvailable;
    setState(() {
      isAvailable = newStatus;
      myPub!.isAvailable = newStatus;
    });

    await FirebaseFirestore.instance
        .collection('pubs')
        .doc(myPub!.id)
        .update({'isAvailable': newStatus});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus
              ? "🚐 ${myPub!.name} ist jetzt wieder verfügbar!"
              : "🚨 ${myPub!.name} ist im Einsatz!",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  Future<void> _saveChanges() async {
    if (myPub == null) return;

    final updatedData = {
      'description': _descController.text,
      if (_selectedImage != null)
        'iconPath': _selectedImage!.path, // optional: Upload zu Storage
    };

    await FirebaseFirestore.instance
        .collection('pubs')
        .doc(myPub!.id)
        .update(updatedData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Änderungen gespeichert ✅")),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
      );
    }

    if (myPub == null) {
      return const Scaffold(
        body: Center(child: Text("Keine Kneipe zugeordnet.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Wirtbereich – ${myPub!.name}"),
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
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔶 Statusbereich
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Status",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🟢 Geöffnet/Geschlossen-Schalter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOpen ? "Geöffnet" : "Geschlossen",
                        style: TextStyle(
                          color: isOpen ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Switch(
                        value: isOpen,
                        onChanged: (_) => _toggleOpenStatus(),
                        activeColor: Colors.greenAccent,
                        inactiveThumbColor: Colors.redAccent,
                      ),
                    ],
                  ),

                  // 🚐 Verfügbarkeit nur bei mobiler Einheit
                  if (myPub!.isMobileUnit) ...[
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isAvailable ? "Bereit" : "Im Einsatz",
                          style: TextStyle(
                            color: isAvailable ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: isAvailable,
                          onChanged: (_) => _toggleAvailability(),
                          activeColor: Colors.greenAccent,
                          inactiveThumbColor: Colors.redAccent,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🔶 Logo bearbeiten
            const Text("Kneipenlogo:",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, height: 150)
                    : Image.asset(
                  myPub!.iconPath.isNotEmpty
                      ? myPub!.iconPath
                      : "assets/icons/default_pub.png",
                  height: 150,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔶 Beschreibung bearbeiten
            const Text("Beschreibung:",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Beschreibe deine Kneipe…",
                hintStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),

            // 🔶 Änderungen speichern
            Center(
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text("Speichern"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 🔶 Gäste anzeigen
            const Text(
              "Aktuell eingecheckte Gäste:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            _buildGuestList(),
          ],
        ),
      ),
    );
  }


  Widget _buildGuestList() {
    if (myPub == null) return const Text("Keine Daten");

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('pubId', isEqualTo: myPub!.id)
          .where('action', isEqualTo: 'check-in')
          .where('timestampEnd', isEqualTo: null)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text("Keine Gäste eingecheckt.",
              style: TextStyle(color: Colors.white70));
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.person, color: Colors.orangeAccent),
              title: Text(data['guestId'] ?? "Unbekannt",
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                "Check-in: ${(data['timestampBegin'] as Timestamp).toDate()}",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
