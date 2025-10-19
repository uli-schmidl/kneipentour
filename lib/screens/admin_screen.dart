import 'package:flutter/material.dart';
import 'package:kneipentour/models/user.dart';
import '../models/pub.dart';
import '../data/pub_manager.dart';
import 'wirt_screen.dart';

class AdminScreen extends StatefulWidget {
  final String adminName;

  const AdminScreen({required this.adminName, super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Pub> pubs = [];

  @override
  void initState() {
    super.initState();
    pubs = PubManager().allPubs;
  }

  void _togglePubStatus(Pub pub) {
    setState(() {
      pub.isOpen = !pub.isOpen;
      PubManager().updatePubStatus(pub.id, pub.isOpen);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pub.isOpen
              ? '🍻 ${pub.name} ist jetzt geöffnet'
              : '🚪 ${pub.name} wurde geschlossen',
        ),
      ),
    );
  }

  void _editPub(Pub pub) {
    // Erstelle einen temporären Benutzer für diese Kneipe
    final tempUser = UserAccount(
      username: pub.name,
      password: '', // kein Passwort nötig hier
      role: UserRole.wirt,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WirtScreen(user: tempUser),
      ),
    ).then((_) {
      setState(() {
        pubs = PubManager().allPubs;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Adminbereich – ${widget.adminName}"),
        backgroundColor: Colors.orange.shade700,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            "Kneipenverwaltung",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          // 🏠 Liste aller Kneipen
          ...pubs.map((pub) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: Image.asset(
                pub.iconPath,
                width: 40,
                height: 40,
              ),
              title: Text(pub.name),
              subtitle: Text(pub.isOpen ? "Geöffnet" : "Geschlossen"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: pub.isOpen,
                    onChanged: (_) => _togglePubStatus(pub),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editPub(pub),
                  ),
                ],
              ),
            ),
          )),

          const SizedBox(height: 24),
          Divider(),
          const SizedBox(height: 16),

          Text(
            "Weitere Optionen",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.chat),
            label: const Text("Wirt-Chat öffnen"),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chat wird bald aktiviert 💬")),
              );
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.image),
            label: const Text("Werbebanner verwalten"),
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("Foto-Termin ändern"),
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.help_outline),
            label: const Text("Hilfsanfragen anzeigen"),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
