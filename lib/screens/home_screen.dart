import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/models/guest.dart';
import 'package:kneipentour/models/checkin.dart';
import 'package:kneipentour/screens/achievement_screen.dart';
import 'package:kneipentour/screens/pub_info_screen.dart';
import 'package:kneipentour/screens/qr_code_scanner.dart';
import 'package:location/location.dart';
import 'stamp_screen.dart';
import 'ranking_screen.dart';
import 'faq_screen.dart';
import '../models/pub.dart';
import '../data/achievement_manager.dart';
import '../widgets/achievement_popup.dart';
import '../data/achievements.dart';
import '../data/challenge_manager.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  HomeScreen({required this.userName});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  LocationData? _currentLocation;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Marker> _guestMarkers = {};
  Map<String, List<CheckIn>> guestCheckIns = {};
  BitmapDescriptor? _currentLocationIcon;
  String currentGuestId = 'gast123'; // später dynamisch vergeben
  Map<String, DateTime> _lastPubNotificationTimes = {};
  final double notificationDistance = 20;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  StreamSubscription? _pubSub;
  StreamSubscription? _guestSub;

  Pub? get _mobilePub {
    try {
      return PubManager().allPubs.firstWhere((p) => p.isMobileUnit);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _pubSub?.cancel();
    _guestSub?.cancel();
    super.dispose();
  }

  void _updateGuestMarkersFromFirestore() {
    GuestManager().getGuestsStream().listen((snapshot) {
      Set<Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final guestId = data['guestId'] ?? 'unknown';
        final lat = (data['latitude'] ?? 0).toDouble();
        final lon = (data['longitude'] ?? 0).toDouble();
        final currentPub = data['currentPubId'];
        final drinks = data['drinksConsumed'] ?? 0;

        final isTopGuest = guestId == _getTopGuestId();

        newMarkers.add(
          Marker(
            markerId: MarkerId("guest_$guestId"),
            position: LatLng(lat, lon),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isTopGuest ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: guestId,
              snippet: currentPub != null
                  ? "🍺 in $currentPub – $drinks Getränke"
                  : "Unterwegs...",
            ),
          ),
        );
      }

      setState(() {
        _guestMarkers = newMarkers;
      });
    });
  }
  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final pubId = response.payload!;
          final pub = PubManager().allPubs.firstWhere(
                (p) => p.id == pubId,
            orElse: () => Pub(
              id: '',
              name: 'Unbekannte Kneipe',
              description: '',
              latitude: 0,
              longitude: 0,
              iconPath: '',
              isMobileUnit: false,
              capacity: 0,
            ),
          );
          if (pub.id.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PubInfoScreen(
                  pub: pub,
                  guestId: currentGuestId,
                  guestCheckIns: guestCheckIns,
                  onCheckIn: _checkInGuest,
                ),
              ),
            );
          }
        }
      },
    );
  }


  void _updateGuestMarkers() {
    Set<Marker> newMarkers = {};

    final topGuestId = _getTopGuestId();

    guestCheckIns.forEach((guestId, checkIns) {
      // Aktuelle Position simulieren (später echte GPS-Daten)
      final randomPub = PubManager().allPubs[guestId.hashCode % PubManager().allPubs.length];
      final latOffset = (guestId.hashCode % 10) / 50000.0;
      final lonOffset = (guestId.hashCode % 10) / 50000.0;

      final guestPosition = LatLng(
        randomPub.latitude + latOffset,
        randomPub.longitude + lonOffset,
      );

      final isTopGuest = guestId == topGuestId;

      newMarkers.add(
        Marker(
          markerId: MarkerId("guest_$guestId"),
          position: guestPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isTopGuest ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: guestId,
            snippet: isTopGuest
                ? "🏆 Führt die Rangliste an!"
                : "Unterwegs auf der Tour...",
          ),
        ),
      );
    });

    setState(() {
      _guestMarkers = newMarkers;
    });
  }


  String? _getTopGuestId() {
    if (guestCheckIns.isEmpty) return null;

    // Sortiere Gäste nach den bekannten Regeln
    var sorted = guestCheckIns.entries.toList()
      ..sort((a, b) {
        int totalA = a.value.fold(0, (sum, c) => sum + c.drinksConsumed);
        int totalB = b.value.fold(0, (sum, c) => sum + c.drinksConsumed);

        if (totalA != totalB) return totalB.compareTo(totalA);

        // Wenn gleich viele Getränke → mehr Kneipen
        int pubsA = a.value.where((c) => c.drinksConsumed > 0).length;
        int pubsB = b.value.where((c) => c.drinksConsumed > 0).length;

        if (pubsA != pubsB) return pubsB.compareTo(pubsA);

        // Wenn immer noch gleich → früheste Zeit des letzten Getränks
        DateTime? timeA = a.value
            .where((c) => c.lastDrinkTime != null)
            .map((c) => c.lastDrinkTime!)
            .fold<DateTime?>(null, (min, t) => min == null || t.isBefore(min) ? t : min);

        DateTime? timeB = b.value
            .where((c) => c.lastDrinkTime != null)
            .map((c) => c.lastDrinkTime!)
            .fold<DateTime?>(null, (min, t) => min == null || t.isBefore(min) ? t : min);

        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;

        return timeA.compareTo(timeB);
      });

    return sorted.first.key; // ID des Top-Gastes
  }


  Future<void> _updateMobileUnitMarker() async {
    final mobilePub = _mobilePub;
    if (mobilePub == null) return;

    // Wähle Icon je nach Status
    final iconPath = mobilePub.isAvailable
        ? mobilePub.iconPath
        : 'assets/icons/mobile_Einsatz.gif';

    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      iconPath,
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == mobilePub.id);
      _markers.add(
        Marker(
          markerId: MarkerId(mobilePub.id),
          position: LatLng(mobilePub.latitude, mobilePub.longitude),
          icon: icon,
          infoWindow: InfoWindow(
            title: mobilePub.name,
            snippet: mobilePub.isAvailable
                ? 'Bereit für den nächsten Auftrag'
                : '🚨 Im Einsatz!',
          ),
        ),
      );
    });
  }




  void _showCheckInNotification(String pubName) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'checkin_channel',
      'Check-in',
      channelDescription: 'Automatischer Check-in bei Kneipenbetreten',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      'Check-in',
      'Du bist jetzt in $pubName eingecheckt!',
      platformDetails,
    );
  }


  void _requestMobileUnit() async {
    final mobilePub = _mobilePub;
    if (mobilePub == null) return;
    if (!mobilePub.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🚨 Mobile Einheit ist derzeit im Einsatz.")),
      );
      return;
    }

    // Einheit wird belegt
    setState(() {
      mobilePub.isAvailable = false;
    });
    PubManager().updatePubStatus(mobilePub.id, false);

    _showNotificationToMobileUnit();
    await _updateMobileUnitMarker();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mobile Einheit wurde informiert!")),
    );
  }


  void _showNotificationToMobileUnit() async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'mobile_unit_channel',
      'Mobile Einheit',
      channelDescription: 'Benachrichtigung für Mobile Einheit',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      1,
      'Mobile Einheit angefordert!',
      'Gast $currentGuestId benötigt Unterstützung.',
      NotificationDetails(android: androidDetails),
    );
  }



  List<Widget> get screens {
    return [
      _buildMap(),
      StampScreen(
        guestId: currentGuestId,
        guestCheckIns: guestCheckIns,
        onCheckIn: _checkInGuest,
      ),
      RankingScreen(guestCheckIns: guestCheckIns),
      AchievementScreen(),
      FaqScreen(),

    ];
  }


  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadCurrentLocationIcon();
    _initLocation();
    PubManager().loadPubs().then((_) {
      _loadPubMarkers();
    });
    _updateGuestMarkersFromFirestore();
    Timer.periodic(const Duration(seconds: 15), (_) => _updateGuestMarkers());
    Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadCurrentLocationIcon() async {
    final ByteData data = await rootBundle.load('assets/icons/me.png');
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 40,
      targetHeight: 96,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final Uint8List bitmap = (await frame.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

    _currentLocationIcon = BitmapDescriptor.fromBytes(bitmap);

    if (_currentLocation != null) _updateCurrentLocationMarker();
  }

  void _updateCurrentLocationMarker() {
    if (_currentLocation == null || _currentLocationIcon == null) return;
    final marker = Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
      icon: _currentLocationIcon!,
      infoWindow: const InfoWindow(title: 'Du bist hier'),
    );
    _markers.removeWhere((m) => m.markerId.value == 'current_location');
    _markers.add(marker);
    setState(() {});
  }



  void _initLocation() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await location.requestService();
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }

    _currentLocation = await location.getLocation();

    location.onLocationChanged.listen((loc) {
      if (!mounted) return;
      _currentLocation = loc;
      _updateCurrentLocationMarker();

      // 🔄 Synchronisiere Standort des Gastes mit Firestore
      GuestManager().updateGuestLocation(
        guestId: currentGuestId,
        latitude: loc.latitude ?? 0,
        longitude: loc.longitude ?? 0,
      );
      _autoCheckIn();
      setState(() {});
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
      ),
    );
  }



  void _autoCheckIn() {
    if (_currentLocation == null) return;
    for (var pub in PubManager().allPubs.where((p) => p.isOpen)) {
      double distance = _calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        pub.latitude,
        pub.longitude,
      );
      if (distance <= notificationDistance) {
        _notifyNearbyPub(pub);
      } else if (distance > (notificationDistance * 2)) {
        _lastPubNotificationTimes.remove(pub.id);
      }
    }
  }


  void _notifyNearbyPub(Pub pub) async {
    final now = DateTime.now();
    final last = _lastPubNotificationTimes[pub.id];
    const cooldownMinutes = 3;
    if (last != null && now.difference(last).inMinutes < cooldownMinutes) return;
    _lastPubNotificationTimes[pub.id] = now;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'nearby_pub_channel',
      'Kneipen in der Nähe',
      channelDescription: 'Benachrichtigt, wenn du dich in der Nähe einer Kneipe befindest',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      pub.id.hashCode,
      '🍻 In der Nähe: ${pub.name}',
      'Du bist nur wenige Meter von ${pub.name} entfernt – möchtest du einchecken?',
      platformDetails,
      payload: pub.id,
    );
  }




  // GoogleMap Widget aktualisieren
  Widget _buildMap() {
    const String darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#4c4c4c"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1c1c1c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]},
  {"featureType": "poi", "elementType": "all", "stylers": [{ "visibility": "off" }]},
  {"featureType": "transit", "elementType": "all", "stylers": [{ "visibility": "off" }]}
]
''';
   // {"featureType": "building", "elementType": "geometry.fill", "stylers": [{"color": "#303030"}]},
   // {"featureType": "building", "elementType": "geometry.stroke", "stylers": [{"color": "#383838"}]}
    if (_currentLocation == null) {
      return Center(child: CircularProgressIndicator());
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        zoom: 15,
      ),
      myLocationEnabled: false,
      myLocationButtonEnabled: true,
        style: darkMapStyle,
        onMapCreated: (controller) {
        _mapController = controller;
       // _mapController?.setMapStyle(darkMapStyle);
        // Optional: die Kamera auf die Kneipen erweitern
        _fitMapToMarkers();
      },
      markers: {..._markers, ..._guestMarkers},
    );
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty) return;

    LatLngBounds bounds;
    var latitudes = _markers.map((m) => m.position.latitude);
    var longitudes = _markers.map((m) => m.position.longitude);

    bounds = LatLngBounds(
      southwest: LatLng(latitudes.reduce((a, b) => a < b ? a : b),
          longitudes.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(latitudes.reduce((a, b) => a > b ? a : b),
          longitudes.reduce((a, b) => a > b ? a : b)),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobilePub = _mobilePub;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 8,
        shadowColor: Colors.orangeAccent.withOpacity(0.3),
        title: Row(
          children: [
            const Icon(Icons.local_bar, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              "Kneipentour",
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                shadows: [
                  Shadow(
                    color: Colors.orangeAccent.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.orangeAccent),
            tooltip: 'QR-Code scannen',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QRScannerScreen(
                    guestId: currentGuestId!,
                    guestCheckIns: guestCheckIns,
                    onCheckIn: _checkInGuest,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: _selectedIndex == 0
          ? Column(
        children: [
          // Karte nimmt 2/3 des Bildschirms ein
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.66,
            child: _buildMap(),
          ),

          // Unteres Drittel: Zusatzinfos oder Platzhalter
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (_) {
                  final nextPub = _getNextUnvisitedPub();

                  if (nextPub == null) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                        SizedBox(height: 8),
                        Text(
                          "Alle Kneipen besucht – Prost! 🍺",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }

                  final distance = _calculateDistance(
                    _currentLocation?.latitude ?? 0,
                    _currentLocation?.longitude ?? 0,
                    nextPub.latitude,
                    nextPub.longitude,
                  ).round();

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "🧭 Nächste offene Kneipe:",
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PubInfoScreen(
                                pub: nextPub,
                                guestId: currentGuestId,
                                guestCheckIns: guestCheckIns,
                                onCheckIn: _checkInGuest,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          nextPub.name,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$distance m entfernt",
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.medical_services),
                        label: Text(
                          mobilePub == null
                              ? "Mobile Einheit nicht verfügbar"
                              : (mobilePub.isAvailable
                              ? "Mobile Einheit anfordern"
                              : "🚨 Einheit unterwegs..."),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mobilePub == null || !mobilePub.isAvailable
                              ? Colors.grey.shade800
                              : Colors.orangeAccent,
                          disabledForegroundColor: Colors.white54,
                        ),
                        onPressed: mobilePub == null || !mobilePub.isAvailable
                            ? null
                            : _requestMobileUnit,
                      ),
                    ],
                  );
                },
              ),
            ),
    ),
    ],
    )
        : screens[_selectedIndex],
    bottomNavigationBar: BottomNavigationBar(
    currentIndex: _selectedIndex,
    onTap: _onItemTapped,
    selectedItemColor: Colors.orangeAccent,
    unselectedItemColor: Colors.grey,
    items: [
    BottomNavigationBarItem(icon: Icon(Icons.map), label: "Karte"),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: "Stempelkarte"),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: "Ranking"),
      BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: "Erfolge"),
      BottomNavigationBarItem(icon: Icon(Icons.help), label: "FAQ"),
        ],
      ),
    );
  }

  final Map<String, BitmapDescriptor> _iconCache = {};

  Future<BitmapDescriptor> _getIcon(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 96, targetHeight: 96);
    final frame = await codec.getNextFrame();
    final bytes = (await frame.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _loadPubMarkers() async {
    _markers.removeWhere((m) => m.markerId.value.startsWith('pub_'));
    final allPubs = PubManager().allPubs;

    for (var pub in allPubs) {
      if (pub.isMobileUnit && !pub.isOpen) continue;
      final iconPath = pub.isOpen ? pub.iconPath : 'assets/icons/closed.png';
      final icon = await _getIcon(iconPath);

      _markers.add(Marker(
        markerId: MarkerId(pub.id),
        position: LatLng(pub.latitude, pub.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: pub.name,
          snippet: pub.description,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PubInfoScreen(
                  pub: pub,
                  guestId: currentGuestId,
                  guestCheckIns: guestCheckIns,
                  onCheckIn: _checkInGuest,
                ),
              ),
            );
          },
        ),
      ));
    }

    setState(() {});
  }


  Future<void> tryCheckIn(String guestId) async {
    if (_currentLocation == null) return;

    PubManager().allPubs.forEach((pub) {
      double distance = _calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        pub.latitude,
        pub.longitude,
      );

      if (distance <= 50) { // weniger als 50 Meter
        _checkInGuest(guestId, pub.id);
      }
    });
  }

  void _checkInGuest(String guestId, String pubId, {bool consumeDrink = false}) async {
    guestCheckIns.putIfAbsent(guestId, () => []);
    var checkIns = guestCheckIns[guestId]!;
    var existing = checkIns.firstWhere(
          (c) => c.pubId == pubId,
      orElse: () => CheckIn(pubId: pubId, guestId: guestId),
    );

    bool isFirstCheckIn = !checkIns.contains(existing);
    if (isFirstCheckIn) checkIns.add(existing);

    if (consumeDrink) {
      existing.drinksConsumed++;
      existing.lastDrinkTime = DateTime.now();
      await GuestManager().addDrink(guestId, pubId, existing.pubId);
    } else if (isFirstCheckIn) {
      await GuestManager().addVisit(guestId, pubId, existing.pubId);
    }

    setState(() {});
  }

  void _showAchievementPopup(BuildContext context, String id) {
    final achievement = AchievementManager()
        .achievements
        .firstWhere((a) => a.id == id);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.of(context).pop();
        });
        return AchievementPopup(achievement: achievement);
      },
    );
  }



  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }

  void _updatePubStatus(String pubId, bool newStatus) {
    final index = PubManager().allPubs.indexWhere((p) => p.id == pubId);
    if (index != -1) {
      setState(() {
        PubManager().allPubs[index].isOpen = newStatus;
      });
      _loadPubMarkers(); // Marker sofort neu laden
    }
  }
  Pub? _getNextUnvisitedPub() {
    // Hole alle offenen Kneipen
    final openPubs = PubManager().allPubs.where((p) => p.isOpen && !p.isMobileUnit).toList();
    if (_currentLocation == null || openPubs.isEmpty) return null;

    // Liste der bereits besuchten Kneipen
    final visitedPubIds = guestCheckIns[currentGuestId]
        ?.where((c) => c.drinksConsumed > 0)
        .map((c) => c.pubId)
        .toSet() ??
        {};

    // Filtere unbesuchte Kneipen
    final unvisited = openPubs.where((p) => !visitedPubIds.contains(p.id)).toList();
    if (unvisited.isEmpty) return null;

    // Finde die nächstgelegene
    unvisited.sort((a, b) {
      final distA = _calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        a.latitude,
        a.longitude,
      );
      final distB = _calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    return unvisited.first;
  }



}
