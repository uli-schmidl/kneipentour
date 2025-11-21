import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kneipentour/data/connection_service.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/data/sync_manager.dart';
import 'screens/start_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);
}

Future<void> _initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  // WICHTIG für iOS: explizit um Erlaubnis fragen
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Token holen & speichern
  final token = await messaging.getToken();
  debugPrint('FCM Token: $token');
  // hier: in Firestore / GuestManager speichern
}

void main() async{
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }

    try {
      await _initNotifications();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }

    try {
      await _initFirebaseMessaging();
    } catch (e) {
      debugPrint('FirebaseMessaging init failed: $e');
    }



  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("📩 Push im Vordergrund empfangen: ${message.notification?.title}");

    // Lokale Notification anzeigen
    flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mobile_unit', 'Mobile Einheit',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  });

  Connectivity().onConnectivityChanged.listen((results) async {
    final isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (isOnline) {
      await SyncManager.processPendingActions();
    }
  });
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);


  runApp(const KneipentourApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("📬 Hintergrund-Nachricht erhalten: ${message.notification?.title}");
}

class KneipentourApp extends StatelessWidget {
  const KneipentourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kneipentour 2025',
      navigatorKey: PubManager().navigatorKey,
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
          onPrimary: Colors.black,
          onSurface: Colors.white,
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
      ),
      home: const StartScreen(),
    );
  }
}
