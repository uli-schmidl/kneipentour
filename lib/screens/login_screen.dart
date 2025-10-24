import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kneipentour/models/user.dart';
import 'package:kneipentour/screens/home_screen.dart';
import 'package:kneipentour/screens/start_screen.dart';
import 'admin_screen.dart';
import 'wirt_screen.dart';
import 'mobile_unit_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() {
          _errorMessage = "❌ Ungültiger Benutzername ($username) oder Passwort ($password)";
          _isLoading = false;
        });
        return;
      }

      final user = UserAccount.fromFirestore(query.docs.first);

      Widget targetScreen;
      switch (user.role) {
        case UserRole.admin:
          targetScreen = AdminScreen(adminName: user.username);
          break;
        case UserRole.wirt:
          targetScreen = WirtScreen(user: user);
          break;
        case UserRole.mobile:
          targetScreen = MobileUnitScreen(user: user);
          break;
        default:
          targetScreen = HomeScreen(userName: user.username);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => targetScreen),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Fehler beim Login: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Login für Wirte & Admins"),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Benutzername"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Passwort"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _login,
              child: const Text("Anmelden"),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
