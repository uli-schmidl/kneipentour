import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kneipentour/config/location_config.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/data/rank_manager.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/models/activity.dart';
import 'package:kneipentour/screens/achievement_screen.dart';
import 'package:kneipentour/screens/pub_info_screen.dart';
import 'package:location/location.dart';
import 'stamp_screen.dart';
import 'ranking_screen.dart';
import 'info_screen.dart';
import '../models/pub.dart';
import '../data/achievement_manager.dart';
import '../widgets/achievement_popup.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  LocationData? _currentLocation;
  GoogleMapController? _mapController;
  Set<Marker> _guestMarkers = {};
  Set<Marker> _pubMarkers={};
  Marker? _mobileUnitMarker;
  BitmapDescriptor? _currentLocationIcon;
  final double notificationDistance = 20;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Pub? _mobilePubCached;
  Pub? _cachedNextPub;
  // Beispiel: fester Mittelpunkt (z. B. Kirchweihplatz in Seitendorf)
  final LatLng _centerPoint = LocationConfig.centerPoint;
  bool _isWithinAllowedArea=true;
  bool _pubsReady = false;
  bool _locationReady = false;
  String _currentStatus = "unterwegs";


// Sichtbarer Radius in Metern
  final double _visibleRadius = LocationConfig.allowedRadius; // 1 km


  StreamSubscription? _pubSub;
  StreamSubscription? _guestSub;
  StreamSubscription<LocationData>? _locationSubscription;


  Future<void> _loadMobilePub() async {
    _mobilePubCached = await PubManager().getMobileUnit();
    setState(() {});
  }


  @override
  void dispose() {
    _pubSub?.cancel();
    _guestSub?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _maybeUpdateNextPub() async {
    if (!_pubsReady || !_locationReady) return;
    await _checkForNextPubChange();
  }


  void _listenToGuestsAndActivities() {
    GuestManager().getGuestsStream().listen((guestSnap) async {
      final activitiesSnap = await ActivityManager().getActivitiesStream().first;

      final drinksPerGuest = <String, int>{};
      for (var doc in activitiesSnap.docs) {
        final data = doc.data();
        if (data['action'] == 'drink') {
          final id = data['guestId'] ?? '';
          drinksPerGuest[id] = (drinksPerGuest[id] ?? 0) + 1;
        }
      }

      Set<Marker> guestMarkers = {};
      for (var doc in guestSnap.docs) {
        final data = doc.data();
        final guestId = doc.id;
        final lat = (data['latitude'] ?? 0).toDouble();
        final lon = (data['longitude'] ?? 0).toDouble();
        final name = data['name'] ?? 'Gast';
        final drinks = data['drinks'] ?? 0;
        final rank = RankManager().getRankForDrinks(drinks);


        final distance = _calculateDistance(_centerPoint.latitude, _centerPoint.longitude, lat, lon);
        if (distance > _visibleRadius) continue; // 👉 nur innerhalb von 1 km anzeigen

        final icon = await _getIcon("assets/icons/king.png",40,96);

        guestMarkers.add(
          Marker(
            markerId: MarkerId('guest_$guestId'),
            position: LatLng(lat, lon),
            icon: icon,
            infoWindow: InfoWindow(
              title: "${rank.emoji} $name",
            ),
        ),
        );
      }
      if (!mounted) return;
      setState(() {
        _guestMarkers = guestMarkers;
      });
    });
  }


  void _listenToMobileUnitMarker() {
    PubManager().getPubsStream().listen((snapshot) async {
      if (!mounted) return; // ✅ Wenn der Screen nicht mehr existiert → abbrechen

      final mobileDocs = snapshot.docs
          .where((doc) => (doc.data()['isMobileUnit'] ?? false) == true)
          .toList();

      if (mobileDocs.isEmpty) return;

      final mobileDoc = mobileDocs.first;
      final data = mobileDoc.data();

      final pubId = mobileDoc.id;
      final name = data['name'] ?? 'Mobile Einheit';
      final lat = (data['latitude'] ?? 0).toDouble();
      final lon = (data['longitude'] ?? 0).toDouble();
      final isAvailable = data['isAvailable'] ?? true;


      // 🔁 aktualisiere das gecachte Objekt (für den Button)
      _mobilePubCached = Pub(
        id: pubId,
        name: name,
        description: data['description'] ?? '',
        latitude: lat,
        longitude: lon,
        iconPath: data['iconPath'] ?? 'assets/icons/mobile.png',
        isMobileUnit: true,
        isOpen: true,
        capacity: (data['capacity'] ?? 0) is int
            ? data['capacity']
            : int.tryParse(data['capacity']?.toString() ?? '0') ?? 0,
        isAvailable: isAvailable,
      );

      // 🧭 wähle Icon basierend auf Status
      final iconPath = isAvailable
          ? (data['iconPath'] ?? 'assets/icons/mobile.png')
          : 'assets/icons/mobile_Einsatz.gif';

      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        iconPath,
      );
      if (!mounted) return;

      setState(() {
        _mobileUnitMarker = Marker(
          markerId: MarkerId(pubId),
          position: LatLng(lat, lon),
          icon: icon,
          infoWindow: InfoWindow(
            title: name,
            snippet: isAvailable
                ? 'Bereit für den nächsten Auftrag'
                : '🚨 Im Einsatz!',
          ),
        );
      });
    });
  }

  void _listenToPubs() {
    _pubSub = PubManager().getPubsStream().listen((snapshot) async {
      if (!mounted) return;

      final pubs = snapshot.docs.map((doc) {
        final data = doc.data();
        return Pub(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          latitude: (data['latitude'] ?? 0).toDouble(),
          longitude: (data['longitude'] ?? 0).toDouble(),
          iconPath: data['iconPath'] ?? 'assets/icons/pub.png',
          isOpen: data['isOpen'] ?? true,
          isMobileUnit: data['isMobileUnit'] ?? false,
          capacity: (data['capacity'] ?? 0) is int
              ? data['capacity']
              : int.tryParse(data['capacity']?.toString() ?? '0') ?? 0,
        );
      }).toList();

      // 🔥 Prüfen, ob sich etwas wirklich geändert hat
      bool hasChanged = pubs.length != PubManager().allPubs.length ||
          !_listEquals(
            pubs.map((p) => p.id + p.isOpen.toString()).toList(),
            PubManager()
                .allPubs
                .map((p) => p.id + p.isOpen.toString())
                .toList(),
          );

      if (hasChanged) {
        PubManager().allPubs
          ..clear()
          ..addAll(pubs);

        await _loadPubMarkers(); // Marker aktualisieren
        print("🏪 Kneipenmarker neu geladen (${pubs.length})");
      }
    });
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }


  void _requestMobileUnit() async {
    // 🔍 Finde die mobile Einheit aus Firestore (über PubManager)
    final mobilePub = await PubManager().getMobileUnit();
    if (mobilePub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Keine mobile Einheit gefunden.")),
      );
      return;
    }

    if (!mobilePub.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🚨 Mobile Einheit ist derzeit im Einsatz.")),
      );
      return;
    }

    // 🚑 Einheit als "belegt" markieren (Firestore-Update)
    await PubManager().updateAvailability(mobilePub.id, false);
    AchievementManager().notifyAction(AchievementEventType.requestMobileUnit, SessionManager().guestId, pubId: mobilePub.id);

    // 📡 Benachrichtigung an die mobile Einheit
    _showNotificationToMobileUnit();
    await ActivityManager().logActivity(
      Activity(
        id: '',
        guestId: SessionManager().guestId,
        pubId: '', // optional
        action: 'request_mobile',
        timestampBegin: DateTime.now(),
        latitude: _currentLocation!.latitude!,
        longitude: _currentLocation!.longitude!,
      ),
    );

    // ✅ Benutzerfeedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mobile Einheit wurde informiert! 🚐💨")),
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
      'Gast $SessionManager().guestId benötigt Unterstützung.',
      NotificationDetails(android: androidDetails),
    );
  }

  bool _pubsLoaded = false;


  List<Widget> get screens {
    return [
      _buildMap(),
      StampScreen(
        guestId: SessionManager().guestId,
        onCheckIn: _checkInGuest,
        onCheckOut: _checkOutGuest,
        currentLocation: _currentLocation,
      ),
      RankingScreen(),
      AchievementScreen(),
      InfoScreen(),

    ];
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // 🧡 Achievement-Listener aktivieren
    AchievementManager().onAchievementUnlocked = (achievement) {
      if (!mounted) return;
      _showAchievementPopup(context, achievement.id);
    };

    // 👇 kleine Verzögerung, damit Build & Streams fertig sind
    Future.delayed(const Duration(seconds: 2), () {
      _initLocation();
    });
  }

  Future<void> _initializeApp() async {
    await PubManager().loadPubs(); // wirklich abwarten
    await _loadPubMarkers();       // erst danach Marker setzen
    _pubsReady =true;
    setState(() => _pubsLoaded = true);
    _listenToMobileUnitMarker();
    _listenToPubs();
    _listenToGuestsAndActivities();
    _loadCurrentLocationIcon();
    await _initLocation();
    await _loadMobilePub();
    AchievementManager().initialize();
    await _maybeUpdateNextPub();
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
    if (!mounted) return; // ✅ verhindert setState nach dispose
    if (_currentLocation == null || _currentLocationIcon == null) return;

    final selfMarker = Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
      icon: _currentLocationIcon!,
      infoWindow: const InfoWindow(title: 'Du bist hier 🍻'),
    );

    // ⚙️ Gäste-Marker aktualisieren, aber "Du bist hier" immer hinzufügen
    setState(() {
      // Entferne alte Selbst-Marker
      _guestMarkers.removeWhere((m) => m.markerId.value == 'current_location');
      // Füge aktuellen Standort hinzu
      _guestMarkers.add(selfMarker);
    });
  }

  Future<void> _initLocation() async {
    final location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        print("❌ GPS nicht aktiviert");
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }

    if (permissionGranted != PermissionStatus.granted) {
      print("❌ Keine Standortberechtigung");
      return;
    }

    try {
      // ✅ Aktuelle Position initial abrufen
      final loc = await location.getLocation();
      if (loc.latitude != null && loc.longitude != null) {
        _currentLocation = loc;
        final distance = _calculateDistance(
          loc.latitude!,
          loc.longitude!,
          _centerPoint.latitude,
          _centerPoint.longitude,
        );

        final within = distance <= _visibleRadius;
        _isWithinAllowedArea = within;

        print("📍 Erste Position: ${loc.latitude}, ${loc.longitude} → innerhalb Bereich: $_isWithinAllowedArea");

        // Gäste-Standort sofort speichern
        await GuestManager().updateGuestLocation(
          guestId: SessionManager().guestId,
          latitude: loc.latitude!,
          longitude: loc.longitude!,
        );

        // Erste Karte & Marker initialisieren
        if (within) _updateCurrentLocationMarker();
        _locationReady = true;     // ✅ Location ist da
        await _maybeUpdateNextPub(); // 🔔 jetzt können wir das „Nächste Kneipe“-Panel setzen
      }

      // 🔁 Live-Standort-Stream starten
      _locationSubscription = location.onLocationChanged.listen((loc) async {
        if (!mounted) return;
        if (loc.latitude == null || loc.longitude == null) return;

        _currentLocation = loc;

        final distance = _calculateDistance(
          loc.latitude!,
          loc.longitude!,
          _centerPoint.latitude,
          _centerPoint.longitude,
        );
        final within = distance <= _visibleRadius;

        // 👇 Nur wenn sich der Radiusstatus ändert (rein/raus)
        if (within != _isWithinAllowedArea) {
          _isWithinAllowedArea = within;
          print("📍 Bereichsstatus geändert → innerhalb: $within");
          setState(() {}); // nur Statuswechsel → minimaler rebuild
        }

        if (within) {
          // 🔹 Marker-Update (keine komplette UI)
          _updateCurrentLocationMarker();

          // 🔹 Standort in Firestore
          await GuestManager().updateGuestLocation(
            guestId: SessionManager().guestId,
            latitude: loc.latitude!,
            longitude: loc.longitude!,
          );

          // 🔹 Achievement-Event
          AchievementManager().notifyAction(
            AchievementEventType.locationUpdate,
            SessionManager().guestId,
          );

          // 🔹 Optional: nur bei größerer Bewegung "nächste Kneipe" prüfen
          _checkForNextPubChange();
          _checkGuestStatus();
          Timer.periodic(const Duration(seconds: 30), (_) => _checkGuestStatus());

        }
      });
    } catch (e) {
      print("⚠️ Fehler bei getLocation(): $e");
    }
  }

  Future<void> _checkForNextPubChange() async {
    if (_currentLocation == null) return;

    final nextPub = await _getNextUnvisitedPub();
    if (nextPub == null) return;

    // ⚡️ Nur wenn sich etwas ändert, UI aktualisieren
    if (_cachedNextPub == null || _cachedNextPub!.id != nextPub.id) {
      setState(() {
        _cachedNextPub = nextPub;
      });
    }
  }

  Future<void> _checkGuestStatus() async {
    final guestId = SessionManager().guestId;
    final activeCheckIn = await ActivityManager().getCheckInActivity(guestId);

    if (!mounted) return;

    if (activeCheckIn != null && activeCheckIn.pubId.isNotEmpty) {
      final pub = PubManager().allPubs.firstWhere(
            (p) => p.id == activeCheckIn.pubId,
        orElse: () => Pub(
          id: activeCheckIn.pubId,
          name: "Unbekannte Kneipe",
          description: "",
          latitude: 0,
          longitude: 0,
          iconPath: "",
        ),
      );

      setState(() {
        _currentStatus = "in ${pub.name}";
      });
    } else {
      setState(() {
        _currentStatus = "unterwegs";
      });
    }
  }

  // GoogleMap Widget aktualisieren
  Widget _buildMap() {
    if (_currentLocation == null) {
      return const Center(
        child: Text(
          "📍 Standort wird ermittelt...",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final LatLng startPos;
    if (_currentLocation == null ||
        _currentLocation!.latitude == null ||
        _currentLocation!.longitude == null ||
        (_currentLocation!.latitude == 0 && _currentLocation!.longitude == 0)) {
      // 🧭 Fallback: FFW-Haus
      startPos = const LatLng(49.4521, 11.0767);
    } else {
      startPos = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    }


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
      initialCameraPosition: CameraPosition(target: startPos, zoom: 15
      ),
      myLocationEnabled: false,
      myLocationButtonEnabled: true,
        onMapCreated: (controller) {
        _mapController = controller;
        try {
          _mapController?.setMapStyle(darkMapStyle);
        } catch (e) {
          print("⚠️ Map style konnte nicht angewendet werden: $e");
        }
        _fitMapToMarkers();
      },
      markers: {
        ..._pubMarkers,
        ..._guestMarkers,
        if (_mobileUnitMarker != null) _mobileUnitMarker!,
      },
    );
  }

  void _fitMapToMarkers() {
    final allMarkers = {..._pubMarkers, ..._guestMarkers};
    if (_mobileUnitMarker != null) allMarkers.add(_mobileUnitMarker!);

    if (allMarkers.isEmpty) return;

    final latitudes = allMarkers.map((m) => m.position.latitude);
    final longitudes = allMarkers.map((m) => m.position.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(latitudes.reduce(min), longitudes.reduce(min)),
      northeast: LatLng(latitudes.reduce(max), longitudes.reduce(max)),
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
    if (!_pubsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }
    if (!_isWithinAllowedArea) {
      // Nutzer außerhalb des erlaubten Bereichs → StartScreen anzeigen
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, color: Colors.redAccent, size: 60),
                SizedBox(height: 16),
                Text(
                  "🚫 Du bist zu weit weg vom Veranstaltungsgebiet!",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  "Bitte kehre in den Kneipentour-Bereich zurück, um die App zu nutzen.",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 8,
        shadowColor: Colors.orangeAccent.withOpacity(0.3),
        title: ValueListenableBuilder<String?>(
          valueListenable: SessionManager().currentPubId,
          builder: (context, currentPubId, _) {
            final isInPub = currentPubId != null;

            final statusEmoji = isInPub ? "🍻" : "🚶‍♂️";
            final statusText = isInPub ? "in ${PubManager().getPubName(currentPubId)}" : "unterwegs";
            final statusColor = isInPub ? Colors.greenAccent : Colors.white70;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "$statusEmoji $statusText",
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          },
        ),


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
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildNextPubSection(),
                ),
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
      BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: "Info"),
        ],
      ),
    );
  }

  Future<BitmapDescriptor> _getIcon(String path, int targetWidth, int targetHeight) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: targetWidth, targetHeight: targetHeight);
    final frame = await codec.getNextFrame();
    final bytes = (await frame.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _loadPubMarkers() async {
    final pubs = PubManager().allPubs;

    Set<Marker> pubMarkers = {};
    Marker? mobileMarker;

    for (var pub in pubs) {
      final iconPath = pub.isOpen ? pub.iconPath : 'assets/icons/closed.png';
      final icon = await _getIcon(iconPath,96,96);

      final marker = Marker(
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
                  guestId: SessionManager().guestId,
                  onCheckIn: _checkInGuest,
                  onCheckOut: _checkOutGuest,
                  currentLocation: _currentLocation,
                ),
              ),
            );
          },
        ),
      );

      if (pub.isMobileUnit) {
        mobileMarker = marker;
      } else {
        pubMarkers.add(marker);
      }
    }

    setState(() {
      _pubMarkers = pubMarkers;
      _mobileUnitMarker = mobileMarker;
    });
    if (_mapController != null && _pubMarkers.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), _fitMapToMarkers);
    }
  }

  Widget _buildNextPubSection() {
    final nextPub = _cachedNextPub;

    if (nextPub == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.cottage, color: Colors.amber, size: 40),
          SizedBox(height: 8),
        ],
      );
    }

    final distance = _calculateDistance(
      _currentLocation?.latitude ?? 0,
      _currentLocation?.longitude ?? 0,
      nextPub.latitude,
      nextPub.longitude,
    ).round();

    final mobilePub = _mobilePubCached;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("🧭 Nächste noch nicht besuchte Kneipe:",
            style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PubInfoScreen(
                  pub: nextPub,
                  guestId: SessionManager().guestId,
                  onCheckIn: _checkInGuest,
                  onCheckOut: _checkOutGuest,
                  currentLocation: _currentLocation,
                ),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🏷️ Icon links neben Name
              Image.asset(
                nextPub.iconPath.isNotEmpty ? nextPub.iconPath : 'assets/icons/default_pub.png',
                width: 36,
                height: 36,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_bar, color: Colors.orangeAccent, size: 30),
              ),
              const SizedBox(width: 10),
              Text(
                nextPub.name,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        Text("$distance m entfernt",
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
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
          ),
          onPressed:
          mobilePub == null || !mobilePub.isAvailable ? null : _requestMobileUnit,
        ),
      ],
    );
  }


  Future<void> tryCheckIn(String guestId) async {
    if (_currentLocation == null) return;

    for (var pub in PubManager().allPubs) {
      double distance = _calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        pub.latitude,
        pub.longitude,
      );

      if (distance <= 20) { // weniger als 50 Meter
        await _checkInGuest(guestId,pub.id);
      }
    }
  }

  Future<bool> _checkOutGuest(String guestId, String pubId) async {
    AchievementManager().notifyAction(AchievementEventType.checkOut, guestId, pubId: pubId);

    print("🔁 Checkout: $pubId ($guestId)");

    final checkInActivity = await ActivityManager().getCheckInActivity(guestId, pubId: pubId);

    if (checkInActivity != null) {
      checkInActivity.timestampEnd = DateTime.now();
      await ActivityManager().updateActivity(checkInActivity);
      SessionManager().currentPubId.value = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Erfolgreich ausgecheckt!")),
      );
      return true;

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Kein aktiver Check-in gefunden.")),
      );
      return false;

    }
  }


  Future<bool> _checkInGuest(String guestId, String pubId, {bool consumeDrink = false}) async {
    final pub = PubManager().allPubs.firstWhere(
          (p) => p.id == pubId,
      orElse: () => Pub(id: pubId, name: 'Kneipe', description: '', latitude: 0, longitude: 0, iconPath: ''),
    );

    final loc = _currentLocation;
    if (loc == null || loc.latitude == null || loc.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Standort konnte nicht ermittelt werden.")),
      );
      return false;
    }

    // 🧭 Distanz prüfen
    final distance = _calculateDistance(
      loc.latitude!,
      loc.longitude!,
      pub.latitude,
      pub.longitude,
    );

    if (distance > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("📍 Du bist zu weit entfernt (${distance.round()} m) – gehe näher an ${pub.name} heran."),
        ),
      );
      return false;
    }

    // ✅ Alles ok → Check-in
    // 🔁 Falls Gast noch in einer anderen Kneipe eingecheckt ist → automatisch auschecken
    final activeCheckIn = await ActivityManager().getCheckInActivity(guestId);
    SessionManager().currentPubId.value = pubId;
    if (activeCheckIn != null && activeCheckIn.pubId != pubId) {
      print("🔁 Auto-Checkout von alter Kneipe ${activeCheckIn.pubId}");
      activeCheckIn.timestampEnd = DateTime.now();
      await ActivityManager().updateActivity(activeCheckIn);
      AchievementManager().notifyAction(AchievementEventType.checkOut, guestId, pubId: activeCheckIn.pubId);
    }

    AchievementManager().notifyAction(AchievementEventType.checkIn, guestId, pubId: pubId);

    final now = DateTime.now();
    final action = consumeDrink ? 'drink' : 'check-in';

    await ActivityManager().logActivity(
      Activity(
        id: '',
        guestId: SessionManager().guestId,
        pubId: pubId,
        action: action,
        timestampBegin: now,
        latitude: loc.latitude!,
        longitude: loc.longitude!,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🍻 Du bist jetzt in ${pub.name} eingecheckt!")),
    );

    setState(() {});
    return true;
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

  Future<Pub?> _getNextUnvisitedPub() async {
    final openPubs = PubManager().allPubs.where((p) => p.isOpen && !p.isMobileUnit).toList();
    if (_currentLocation == null || openPubs.isEmpty) return null;

    final visited = await ActivityManager().getVisitedPubIds(SessionManager().guestId);
    final unvisited = openPubs.where((p) => !visited.contains(p.id)).toList();
    if (unvisited.isEmpty) return null;

    unvisited.sort((a, b) {
      final da = _calculateDistance(_currentLocation!.latitude!, _currentLocation!.longitude!, a.latitude, a.longitude);
      final db = _calculateDistance(_currentLocation!.latitude!, _currentLocation!.longitude!, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    return unvisited.first;
  }

}
