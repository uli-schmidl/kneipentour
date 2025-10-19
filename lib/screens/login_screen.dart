import 'package:flutter/material.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/models/user.dart';
import '../data/users.dart';
import '../models/pub.dart';
import 'admin_screen.dart';
import 'wirt_screen.dart';
import 'mobile_unit_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  void _login() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final user = users.firstWhere(
          (u) => u.username == username && u.password == password,
      orElse: () => UserAccount(username: "", password: "", role: UserRole.guest),
    );

    if (user.username.isEmpty) {
      setState(() => _errorMessage = "Ungültiger Benutzername oder Passwort");
      return;
    }

    Widget targetScreen;
    switch (user.role) {
      case UserRole.admin:
        targetScreen = AdminScreen(adminName: username);
        break;
      case UserRole.wirt:
        targetScreen = WirtScreen(
          user: user
        );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login für Wirte & Admins")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: "Benutzername"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: "Passwort"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text("Anmelden"),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
