import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kneipentour/screens/login_screen.dart';
import 'package:kneipentour/screens/start_screen.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String aboutText = "";

  @override
  void initState() {
    super.initState();
    _loadAboutText();
  }

  Future<void> _loadAboutText() async {
    try {
      final text = await rootBundle.loadString('assets/info/about.txt');
      setState(() => aboutText = text);
    } catch (e) {
      setState(() => aboutText = "Fehler beim Laden der App-Informationen.");
    }
  }

  Future<void> _switchAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Account wechseln"),
        content: const Text(
            "Möchtest du dich wirklich abmelden und einen anderen Account auswählen?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text("Ja, wechseln"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await SessionManager().clearSession(); // optional: lokale Session löschen

    if (!mounted) return;

    // 👉 zum LoginScreen wechseln
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }


  Future<void> _deleteGuestAccount(BuildContext context) async {
    final guestId = SessionManager().guestId;

    if (guestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Kein Gastkonto gefunden.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Gastkonto löschen"),
        content: const Text(
          "Möchtest du dein Konto wirklich löschen? "
              "Alle deine Aktivitäten und Check-ins gehen verloren.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Löschen"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 🔥 Firebase löschen
      await FirebaseFirestore.instance.collection('guests').doc(guestId).delete();

      final activities = await FirebaseFirestore.instance
          .collection('activities')
          .where('guestId', isEqualTo: guestId)
          .get();

      for (var doc in activities.docs) {
        await doc.reference.delete();
      }

      // 🧹 Lokale Daten löschen
      await SessionManager().reset();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gast-Account gelöscht ✅")),
      );

      // 🏠 Zurück zum Startbildschirm
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StartScreen()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler beim Löschen: $e")),
      );
    }
  }


  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("App-Informationen"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(aboutText, style: const TextStyle(fontSize: 14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Schließen"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Info & Account"),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.switch_account, color: Colors.orangeAccent),
              title: const Text("Account wechseln", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Zwischen Gast, Wirt oder Admin wechseln",
                  style: TextStyle(color: Colors.white70)),
              onTap: _switchAccount,
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text("Gast-Account löschen", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Entfernt alle deine Daten und Aktivitäten",
                  style: TextStyle(color: Colors.white70)),
              onTap: () => _deleteGuestAccount(context), // 👈 Übergibt context korrekt
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
              title: const Text("App-Informationen", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Version, Entwickler, Beschreibung",
                  style: TextStyle(color: Colors.white70)),
              onTap: _showAboutDialog,
            ),
          ],
        ),
      ),
    );
  }
}
