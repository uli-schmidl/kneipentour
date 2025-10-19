import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/start_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // wird automatisch erstellt

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KneipentourApp());
}

class KneipentourApp extends StatelessWidget {
  const KneipentourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kneipentour 2025',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // 👈 immer Dark Mode aktiv
        darkTheme: ThemeData(
          textTheme: GoogleFonts.nunitoTextTheme(
            ThemeData.dark().textTheme,
          ),
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.orangeAccent,
          secondary: Colors.amber,
          surface: Color(0xFF121212),
          background: Color(0xFF0E0E0E),
          onPrimary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),

        // 🧡 AppBar Design
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: Colors.orangeAccent),
        ),

        // 🧱 Bottom Navigation Bar
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          selectedItemColor: Colors.orangeAccent,
          unselectedItemColor: Colors.white60,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),

        // 🧈 Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),

        // 🗂️ Cards & Container
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C1C),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: Colors.black45,
        ),

        // 🧑‍🎤 Text Styles
     //   textTheme: const TextTheme(
     //     bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
     //     titleLarge: TextStyle(
     //         color: Colors.orangeAccent,
     //         fontSize: 20,
     //         fontWeight: FontWeight.bold),
     //     headlineSmall: TextStyle(
     //         color: Colors.white,
     //         fontSize: 22,
     //         fontWeight: FontWeight.bold),
     //   ),
      ),

      home: const StartScreen(),
    );
  }
}
