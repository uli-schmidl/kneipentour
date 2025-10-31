import 'package:flutter/material.dart';
import 'package:kneipentour/data/challenge_manager.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/models/challenge.dart';
import 'package:kneipentour/models/user.dart';
import 'package:kneipentour/screens/start_screen.dart';
import '../models/pub.dart';
import '../data/pub_manager.dart';
import 'wirt_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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
      assignedPubId: pub.id,
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
  Future<void> _addUserDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.wirt;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Neuen Benutzer hinzufügen"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: "Benutzername"),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Passwort"),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DropdownButton<UserRole>(
                value: selectedRole,
                items: UserRole.values
                    .where((r) => r != UserRole.guest) // Gäste hier nicht relevant
                    .map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.name.toUpperCase()),
                ))
                    .toList(),
                onChanged: (r) => selectedRole = r!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () async {
                final username = usernameController.text.trim();
                final password = passwordController.text.trim();

                if (username.isEmpty || password.isEmpty) return;

                await FirebaseFirestore.instance.collection('users').add({
                  'username': username,
                  'password': password,
                  'role': selectedRole.name,
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Benutzer '$username' hinzugefügt ✅")),
                );
                setState(() {});
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Benutzer gelöscht ❌")),
    );
    setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin-Bereich"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Abmelden",
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Abmelden"),
                  content: const Text("Möchtest du dich wirklich abmelden?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Abbrechen"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Abmelden"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await SessionManager().clearSession();

                if (!context.mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const StartScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
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
            "Benutzerverwaltung",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Text("Noch keine Benutzer angelegt.");
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text(data['username'] ?? 'Unbekannt'),
                      subtitle: Text("Rolle: ${data['role'] ?? 'unbekannt'}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(doc.id),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),
          Divider(),
          const SizedBox(height: 16),

          Text(
            "Challenges",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('challenges').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Text("Noch keine Challenges vorhanden.");
              }

              final challenges = docs.map((doc) =>
                  Challenge.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

              return Column(
                children: challenges.map((challenge) {
                  return Card(
                    child: ListTile(
                      leading: Image.asset(
                        challenge.iconPath,
                        width: 40,
                        height: 40,
                      ),
                      title: Text(challenge.title),
                      subtitle: Text(
                        challenge.isActive
                            ? "Aktiv – endet in ${challenge.remaining.inMinutes} min"
                            : "Inaktiv",
                      ),
                      trailing: Switch(
                        value: challenge.isActive,
                        onChanged: (val) async {
                          await ChallengeManager().toggleChallenge(
                            challenge.id,
                            val,
                            durationMinutes: challenge.durationMinutes,
                          );
                          setState(() {}); // optional, UI-Refresh
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text("Neuen Benutzer hinzufügen"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: _addUserDialog,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
