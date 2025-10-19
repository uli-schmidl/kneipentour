import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/screens/home_screen.dart';
import 'login_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final TextEditingController _nameController = TextEditingController();
  String generatedName = "DurstigerDachs"; // später random generieren
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('guestName');

    if (savedName != null && savedName.isNotEmpty) {
      // 🔹 Gast existiert bereits → direkt weiterleiten
      print("🔁 Automatischer Login als $savedName");
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
    final name = _nameController.text.isEmpty
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

    // 🔹 Prüfen, ob der Name bereits vergeben ist
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

    // 🔹 Firestore: neuen Gast-Eintrag erzeugen
    await GuestManager().createOrUpdateGuest(name, name);

    // 🔹 Lokal speichern
    await prefs.setString('guestName', name);

    // 🔹 Weiter zur HomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: name)),
    );
  }

  void _generateRandomName() async {
    final adjectives = ["Durstiger", "Fröhlicher", "Verwegener", "Beschwipster", "Ausgetrockneter",
      "Bierdurstiger", "Unterhopfter", "Motivierter","Lustiger","Betrunkener","Torkelnder", "Feierwütiger", "Schapsfreudiger", "Bieriger", "Schwankender",
    "Saufender", "Zünftiger", "Lallender", "Prostender","Saufender","Feiernder","Tanzender"];
    final nouns = ["Dachs", "Bierkrug", "Fuchs", "Zapfhahn", "Biber", "Unkerich", "Rehbock", "Mops", "Dackel", "Lümmel", "Frosch","Storch", "Pirat", "Schurke"
    ,"Barde", "Zecher", "Luchs","Lurch","Löwe", "Tiger", "Schwan","Geier","Falke", "Kojote","Rentier","Schluckspecht", "Papst","Tanzbär","Hengst", "Brudi",
      "Pilsprophet","Schnapsritter","Tresentiger"];

    String newName;
    bool exists = true;

    // 🔁 So lange wiederholen, bis ein Name frei ist
    do {
      newName =
      "${adjectives[DateTime.now().millisecond % adjectives.length]}${nouns[DateTime.now().second % nouns.length]}";
      exists = await GuestManager().nameExists(newName);
    } while (exists);

    setState(() {
      generatedName = newName;
    });

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
        body: Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌆 Hintergrundbild
          Image.asset(
            'assets/icons/flyer.jpg',
            fit: BoxFit.cover,
          ),

          // 🌑 Dunkles Overlay
          Container(color: Colors.black.withOpacity(0.6)),

          // 🔐 Login-Icon oben rechts
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.admin_panel_settings,
                  color: Colors.white70, size: 30),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              },
              tooltip: "Login für Wirte & Admins",
            ),
          ),

          // ⚡ Inhalt unten
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

                  // 🧑‍🎤 Namenseingabe
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

                  // 🎲 Zufälligen Namen generieren
                  TextButton(
                    onPressed: _generateRandomName,
                    child: const Text(
                      "Neuen Namen generieren",
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🚀 Start-Button
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
