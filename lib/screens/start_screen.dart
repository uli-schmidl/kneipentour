import 'package:flutter/material.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/screens/home_screen.dart';
import 'login_screen.dart';
import 'dart:math';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final TextEditingController _nameController = TextEditingController();
  String generatedName = "DurstigerDachs";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('guestName');
    if (savedName != null) {
      debugPrint("🔁 Automatischer Login als $savedName");
      SessionManager().initGuest(guestId: savedName, name: savedName);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userName: savedName)),
      );
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _startTour() async {
    final prefs = await SharedPreferences.getInstance();
    final name = _nameController.text.trim().isEmpty
        ? generatedName
        : _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bitte gib einen Namen ein 🍻"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final exists = await GuestManager().nameExists(name);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Der Name '$name' ist bereits vergeben 🍺"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 🔹 Gast-ID == Name
    await GuestManager().createOrUpdateGuest(name, name);

    // 🔹 Lokal speichern
    await prefs.setString('guestName', name);
    await prefs.setString('guestId', name);
    SessionManager().initGuest(guestId: name, name: name);

    // 🔹 Weiter zur HomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: name)),
    );
  }

  /// 🎲 Zufälligen, noch freien Namen generieren
  Future<void> _generateRandomName() async {
    const adjectives = [
      "Durstiger", "Fröhlicher", "Verwegener", "Beschwipster", "Ausgetrockneter",
      "Bierdurstiger", "Unterhopfter", "Motivierter", "Lustiger", "Betrunkener",
      "Torkelnder", "Feierwütiger", "Schnapsfreudiger", "Zünftiger", "Lallender",
      "Saufender", "Prostender", "Feiernder", "Tanzender"
    ];

    const nouns = [
      "Dachs", "Bierkrug", "Fuchs", "Zapfhahn", "Biber", "Rehbock", "Mops",
      "Lümmel", "Pirat", "Schurke", "Barde", "Zecher", "Luchs", "Tiger",
      "Schluckspecht", "Papst", "Tanzbär", "Hengst", "Brudi", "Pilsprophet"
    ];

    final rnd = Random();
    String newName;
    bool exists;

    do {
      newName = "${adjectives[rnd.nextInt(adjectives.length)]}${nouns[rnd.nextInt(nouns.length)]}";
      exists = await GuestManager().nameExists(newName);
    } while (exists);

    setState(() => generatedName = newName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("💡 Vorschlag: $generatedName ist noch frei!"),
        backgroundColor: Colors.greenAccent.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/icons/flyer.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.6)),

          // 🔐 Admin-Login
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white70, size: 30),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              ),
              tooltip: "Login für Wirte & Admins",
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Kneipentour 2025",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white12,
                      hintText: generatedName,
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _generateRandomName,
                    child: const Text(
                      "Neuen Namen generieren",
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.local_bar),
                    label: const Text("Tour starten"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _startTour,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
