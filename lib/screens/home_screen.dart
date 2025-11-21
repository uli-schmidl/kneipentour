import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kneipentour/config/location_config.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/data/challenge_manager.dart';
import 'package:kneipentour/data/connection_service.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/rank_manager.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/models/activity.dart';
import 'package:kneipentour/screens/achievement_screen.dart';
import 'package:kneipentour/screens/info_screen.dart';
import 'package:kneipentour/screens/pub_info_screen.dart';
import 'package:kneipentour/screens/ranking_screen.dart';
import 'package:kneipentour/screens/stamp_screen.dart';
import 'package:kneipentour/util/Utilities.dart';
import 'package:kneipentour/widgets/achievement_popup.dart';
import '../models/pub.dart';


class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

// Marker-Sets
  final Set<Marker> _pubMarkers = {};
  final Set<Marker> _guestMarkers = {};
  Marker? _selfMarker;
  Marker? _mobileUnitMarker;

// Icons (Self + Emojis)
  BitmapDescriptor? _currentLocationIcon;
  BitmapDescriptor? _emojiIconKing;
  BitmapDescriptor? _emojiIconBeer;
  BitmapDescriptor? _emojiIconNoob;

  final LatLng _centerPoint = LocationConfig.centerPoint;
  final double _visibleRadius = LocationConfig.allowedRadius;

  bool _pubsReady = false;
  bool _pubsLoaded = false;
  bool _isWithinAllowedArea = true;

  Position? _currentLocation;
  Pub? _mobilePubCached;
  Pub? _cachedNextPub;

// Streams/Listener
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pubSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _guestSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeCheckinsSub;
  VoidCallback? _locationListener;
  final Map<String, BitmapDescriptor> _iconCache = {};


// Füllstände (pubId -> count)
  Map<String, int> _activeCounts = {};



    @override
  void dispose() {
    _pubSub?.cancel();
    _guestSub?.cancel();
    _activeCheckinsSub?.cancel();

    if (_locationListener != null) {
      SessionManager().lastKnownLocation.removeListener(_locationListener!);
      _locationListener = null;
    }
    super.dispose();
  }

  Future<BitmapDescriptor> _iconFromAsset(String path, int widthPx, int heightPix) async {
    final key = '$path@$widthPx';
    final cached = _iconCache[key];
    if (cached != null) return cached;

    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: widthPx,
      targetHeight: heightPix,
    );
    final frame = await codec.getNextFrame();
    final bytes = (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer.asUint8List();

    final icon = BitmapDescriptor.fromBytes(bytes);
    _iconCache[key] = icon;
    return icon;
  }


  Future<void> _maybeUpdateNextPub() async {
    if (!_pubsReady) return;
    await _checkForNextPubChange();
  }


  void _listenToGuestsAndActivities() {
    _guestSub?.cancel();
    _guestSub = GuestManager().getGuestsStream().listen((guestSnap) async {
      // aktive Checkins holen, um Gäste in Kneipen zu ignorieren
      final openCheckInsSnap = await FirebaseFirestore.instance
          .collection('activities')
          .where('action', isEqualTo: 'check-in')
          .where('timestampEnd', isNull: true)
          .get();
      final checkedInGuestIds = openCheckInsSnap.docs
          .map((d) => d['guestId'] as String)
          .toSet();

      // Drinks (für Ranking)
      final acts = await ActivityManager().getActivitiesStream().first;
      final drinksPerGuest = <String, int>{};
      for (var doc in acts.docs) {
        final data = doc.data();
        if (data['action'] == 'drink') {
          final gid = data['guestId'] ?? '';
          drinksPerGuest[gid] = (drinksPerGuest[gid] ?? 0) + 1;
        }
      }

      final Set<Marker> newGuestMarkers = {};
      for (final doc in guestSnap.docs) {
        final data = doc.data();
        final gid = doc.id;
        if (SessionManager().guestId==gid) continue;
        if (checkedInGuestIds.contains(gid)) continue;

        final lat = (data['latitude'] ?? 0).toDouble();
        final lon = (data['longitude'] ?? 0).toDouble();
        if (lat == 0 || lon == 0) continue;

        // nur im sichtbaren Radius
        final distance = LocationConfig.calculateDistance(
            _centerPoint.latitude, _centerPoint.longitude, lat, lon);
        if (distance > _visibleRadius) continue;

        final drinks = drinksPerGuest[gid] ?? 0;
        final rank = RankManager().getRankForDrinks(drinks);

        // Emoji-Icon wählen
        final BitmapDescriptor icon = drinks >= 10
            ? (_emojiIconKing ?? BitmapDescriptor.defaultMarker)
             :(_emojiIconBeer ?? BitmapDescriptor.defaultMarker);

        newGuestMarkers.add(
          Marker(
            markerId: MarkerId('guest_$gid'),
            position: LatLng(lat, lon),
            icon: icon,
            infoWindow: InfoWindow(
              title: "${rank.emoji} $gid",
              snippet: "Getränke: $drinks",
            ),
            zIndex: 10,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _guestMarkers
          ..clear()
          ..addAll(newGuestMarkers);
      });
    });
  }

  void _listenToPubs() {
    _pubSub?.cancel();
    _pubSub = PubManager().getPubsStream().listen((snapshot) async {
      if (!mounted) return;

      // PubManager aktualisieren
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

      PubManager().allPubs
        ..clear()
        ..addAll(pubs);

      // Pub-Marker aus Füllständen neu zeichnen
      _rebuildPubMarkersFromCounts();

      if (mounted && !_pubsLoaded) {
        setState(() => _pubsLoaded = true);
      }
    });
  }


  void _listenActiveFillLevels() {
    _activeCheckinsSub?.cancel();
    _activeCheckinsSub = FirebaseFirestore.instance
        .collection('activities')
        .where('action', isEqualTo: 'check-in')
        .where('timestampEnd', isNull: true)
        .snapshots()
        .listen((qs) {
      final counts = <String, int>{};
      for (final d in qs.docs) {
        final pid = (d.data()['pubId'] ?? '') as String;
        if (pid.isEmpty) continue;
        counts[pid] = (counts[pid] ?? 0) + 1;
      }

      // nur updaten, wenn sich wirklich was ändert
      final changed = counts.length != _activeCounts.length ||
          counts.entries.any((e) => _activeCounts[e.key] != e.value);
      if (!changed) return;

      _activeCounts = counts;
      _rebuildPubMarkersFromCounts();
      if (mounted) setState(() {});
    });
  }

  // ⏱ letzter Aufrufzeitpunkt
  DateTime? _lastRebuildCall;
// 🚫 verhindert mehrfach gleichzeitiges Rendern
  bool _isRebuildingPubs = false;

  Future<void> _rebuildPubMarkersFromCounts() async {
    // 🛑 Wenn noch keine Pubs geladen sind → später nochmal versuchen
    if (PubManager().allPubs.isEmpty) {
      print("⏳ Noch keine Pubs geladen – versuche erneut in 1s...");
      Future.delayed(const Duration(seconds: 1), _rebuildPubMarkersFromCounts);
      return;
    }

    // 🧯 Throttle: wenn innerhalb von 800 ms schon einmal ausgeführt → überspringen
    final now = DateTime.now();
    if (_lastRebuildCall != null &&
        now.difference(_lastRebuildCall!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastRebuildCall = now;

    if (_isRebuildingPubs) return;
    _isRebuildingPubs = true;

    try {
      _pubMarkers.clear();
      Marker? mobile;

      for (final pub in PubManager().allPubs) {
        final currentGuests = _activeCounts[pub.id] ?? 0;
        final capacity = pub.capacity;
        final fill = capacity > 0 ? currentGuests / capacity : 0.0;

        String fullnessText;
        if (pub.isMobileUnit) {
          fullnessText = pub.isAvailable ? "Bereit!" : "Im Einsatz!";
        } else {
          if (fill < 0.5) {
            fullnessText = "🟢 rankommen!";
          } else if (fill < 0.75) {
            fullnessText = "🟠 gmidli";
          } else if (fill < 1) {
            fullnessText = "🔴 kuschelig";
          } else {
            fullnessText = "🔥 voll";
          }
          fullnessText = "$currentGuests / $capacity · $fullnessText";
        }

        // 🧩 Icons cachen + laden
        final icon = await _iconFromAsset(
          pub.isOpen ? pub.iconPath : 'assets/icons/closed.png',
          104,
          104,
        );

        final marker = Marker(
          markerId: MarkerId(pub.id),
          position: LatLng(pub.latitude, pub.longitude),
          icon: icon,
          zIndexInt: pub.isMobileUnit ? 100 : 50,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PubInfoScreen(
                  pub: pub,
                  guestId: SessionManager().guestId,
                  onCheckIn: _checkInGuest,
                  onCheckOut: _checkOutGuest,
                ),
              ),
            );

            if (result == PubAction.checkedIn || result == PubAction.checkedOut || result == PubAction.drink) {
              _listenToGuestsAndActivities();
              _listenActiveFillLevels();
            }
          },

          /*infoWindow: InfoWindow(
            title: pub.name,
            snippet: fullnessText,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PubInfoScreen(
                    pub: pub,
                    guestId: SessionManager().guestId,
                    onCheckIn: _checkInGuest,
                    onCheckOut: _checkOutGuest,
                  ),
                ),
              );

              if (result == PubAction.checkedIn ||
                  result == PubAction.checkedOut ||
                  result == PubAction.drink) {
                print("🔄 Kneipendaten geändert → Refresh der Karte");
                _listenToGuestsAndActivities();
                _listenActiveFillLevels();
              }
            },
          ),*/
        );

        if (pub.isMobileUnit) {
          mobile = marker;
        } else {
          _pubMarkers.add(marker);
        }
      }

      _mobileUnitMarker = mobile;

      if (mounted) {
        setState(() {});
      }
    } catch (e, st) {
      print("❌ Fehler beim Rebuild der Pubs: $e\n$st");
    } finally {
      _isRebuildingPubs = false;
    }
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
    await ChallengeManager().evaluateProgress(SessionManager().guestId);

    // 📡 Benachrichtigung an die mobile Einheit
    //_showNotificationToMobileUnit();
    await ActivityManager().logActivity(
      Activity(
        id: '',
        guestId: SessionManager().guestId,
        pubId: '', // optional
        action: 'request_mobile',
        timestampBegin: DateTime.now(),
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      ),
    );

    // ✅ Benutzerfeedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mobile Einheit wurde informiert! 🚐💨")),
    );
    ActivityManager().sendPushToMobileUnit(guestName: SessionManager().guestId);
  }


  List<Widget> get screens {
    return [
      _buildMap(),
      StampScreen(
        guestId: SessionManager().guestId,
        onCheckIn: _checkInGuest,
        onCheckOut: _checkOutGuest,
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
    AchievementManager().initialize(); // 🔥 wichtig, muss VOR erstem notifyAction stehen
    AchievementManager().onAchievementUnlocked = (achievement) {
      _showAchievementPopup(achievement);
    };
    Future.microtask(() async {
      await AchievementManager().loadUnlockedFromFirestore(SessionManager().guestId);
    });
    // Standort-Listener aus SessionManager (ValueNotifier)
    _locationListener = () async {
      if (!mounted) return;
      final pos = SessionManager().lastKnownLocation.value;
      if (pos == null) return;

      _currentLocation = pos;
      _updateSelfMarker();           // großer Self-Marker
      await _maybeUpdateNextPub();   // „nächste Kneipe“ neu bewerten

      final distanceToCenter = LocationConfig.calculateDistance(
          pos.latitude, pos.longitude, _centerPoint.latitude, _centerPoint.longitude);
      final inside = distanceToCenter <= _visibleRadius;
      if (inside != _isWithinAllowedArea && mounted) {
        setState(() => _isWithinAllowedArea = inside);
      }
    };
    SessionManager().lastKnownLocation.addListener(_locationListener!);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Nachricht im Vordergrund erhalten: ${message.notification?.title}');
      final title = message.notification?.title ?? "Push";
      final body = message.notification?.body ?? "";

      // ✅ Snackbar oder Dialog anzeigen:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$title\n$body")),
      );
    });
  }

  Future<void> _initializeApp() async {
    // Pubs laden, Marker vorbereiten
    await PubManager().loadPubs();
    await _ensureEmojiIcons();
    await _loadSelfIcon();

    _currentLocation = SessionManager().lastKnownLocation.value;
    _updateSelfMarker();

    // Live-Listener starten
    _listenToPubs();
    _listenActiveFillLevels();       // Füllstände
    _listenToGuestsAndActivities();  // Gäste bewegen

    _pubsReady = true;
    if (mounted) setState(() => _pubsLoaded = true);

    await _maybeUpdateNextPub();
  }

  Future<void> _loadSelfIcon() async {
    // eigener Marker soll groß sein
    final data = await rootBundle.load('assets/icons/me.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 40,   // groß
      targetHeight: 96,
    );
     _currentLocationIcon = await _iconFromAsset('assets/icons/me.png', 40,96); // schön groß
  }

  Future<void> _ensureEmojiIcons() async {
    if (_emojiIconKing != null) return;
    _emojiIconKing = await _emojiToBitmap('👑', 64);
    _emojiIconBeer = await _emojiToBitmap('🍺', 56);
    _emojiIconNoob = await _emojiToBitmap('🌱', 48);
  }

  Future<BitmapDescriptor> _emojiToBitmap(String emoji, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: emoji, style: TextStyle(fontSize: size.toDouble()));
    tp.layout();
    tp.paint(canvas, const Offset(0, 0));
    final pic = recorder.endRecording();
    final img = await pic.toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }


  Future<void> _checkForNextPubChange() async {
    final pos = SessionManager().lastKnownLocation.value;
    if (pos == null) return;

    Pub? nextPub = await _getNextUnvisitedPub();
    nextPub ??= _getNextPub();

    // ⚡️ Nur wenn sich etwas ändert, UI aktualisieren
    if(!mounted)return;

    if (_cachedNextPub == null || _cachedNextPub!.id != nextPub!.id) {
      setState(() {
        _cachedNextPub = nextPub;
      });
    }
  }

  // GoogleMap Widget aktualisieren
  Widget _buildMap() {
    if (Platform.isIOS) {
      // Temporärer Fallback für iOS
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Die Live-Karte ist auf iOS in dieser Version noch deaktiviert.\n'
                'Du kannst trotzdem alle Funktionen (Check-in, Drinks, Challenges) nutzen.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final pos = _currentLocation ?? SessionManager().lastKnownLocation.value;
    if (pos == null) {
      return const Center(
        child: Text("📍 Standort wird ermittelt...",
            style: TextStyle(color: Colors.white70)),
      );
    }

    final startPos = LatLng(pos.latitude, pos.longitude);



    final markers = <Marker>{
      ..._pubMarkers,
      ..._guestMarkers,
      if (_mobileUnitMarker != null) _mobileUnitMarker!,
      if (_selfMarker != null) _selfMarker!, // Self ganz am Ende hinzufügen
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: startPos, zoom: 15),
      myLocationEnabled: false,
      myLocationButtonEnabled: true,
      style: Utilities.darkMapStyle,
      markers: markers,
    );
  }
  void _onItemTapped(int index) {
    if(!mounted)return;

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
        title: StreamBuilder<bool>(
          stream: ConnectionService().connectivityStream,
          builder: (context, snapshot) {
            final isOnline = snapshot.data ?? true;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: SessionManager().currentPubId,
                  builder: (context, currentPubId, _) {
                    final isInPub = currentPubId != null;

                    final statusEmoji = isInPub ? "🍻" : "🚶‍♂️";
                    final statusText = isInPub
                        ? "in ${PubManager().getPubName(currentPubId)}"
                        : "unterwegs";
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

                const SizedBox(width: 12),

                // 🟢 / 🔴 Online-Status
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.greenAccent : Colors.redAccent,
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
            height: MediaQuery.of(context).size.height * 0.5,
            child: _buildMap(),
          ),

          // Unteres Drittel: Zusatzinfos oder Platzhalter
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Center(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: SessionManager().currentPubId,
                    builder: (_, currentPubId, ___) => _buildNextPubSection(),
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



  Widget _buildNextPubSection() {
    final currentPubId = SessionManager().currentPubId.value;


    // 🟢 FALL 1: Nutzer ist aktuell in einer Kneipe
    if (currentPubId != null) {
      final pub = PubManager().allPubs.firstWhere((p) => p.id == currentPubId);
      final guests = _activeCounts[pub.id] ?? 0;
      final fill = guests / pub.capacity;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "🍻 Du bist aktuell eingecheckt in:",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PubInfoScreen(
                    pub: pub,
                    guestId: SessionManager().guestId,
                    onCheckIn: _checkInGuest,
                    onCheckOut: _checkOutGuest,
                  ),
                ),
              ).then((result) async {
                if (!mounted) return;
                if (result is Map && result['changed'] == true) {
                  await _maybeUpdateNextPub();
                  setState(() {});
                }
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  pub.iconPath.isNotEmpty ? pub.iconPath : 'assets/icons/default_pub.png',
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) =>
                  const Icon(Icons.local_bar, color: Colors.orangeAccent, size: 30),
                ),
                const SizedBox(width: 10),
                Text(
                  pub.name,
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Auschecken"),
            onPressed: () async {
              await _checkOutGuest(SessionManager().guestId, pub.id);
              await _maybeUpdateNextPub(); // 🟢 UI sofort neu berechnen
            },
          ),
        ],
      );
    }

    // 🟡 FALL 2: Nutzer ist NICHT in einer Kneipe → nächste unbesuchte Kneipe anzeigen
    _cachedNextPub ??= _getNextPub();
    final nextPub = _cachedNextPub;


    final distance = LocationConfig.calculateDistance(
      _currentLocation?.latitude ?? 0,
      _currentLocation?.longitude ?? 0,
      nextPub!.latitude,
      nextPub.longitude,
    ).round();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        ValueListenableBuilder<String?>(
          valueListenable: SessionManager().currentPubId,
          builder: (_, currentPubId, __) {

            // ✅ Nutzer ist eingecheckt
            if (currentPubId != null) {
              final currentPub = PubManager().getPubById(currentPubId);
              return Column(
                children: [
                  Text(
                    "🍻 Du bist aktuell eingecheckt in:",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentPub?.name ?? "Unbekannt",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text("Auschecken"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _checkOutGuest(SessionManager().guestId, currentPubId),
                  ),
                ],
              );
            }
            final guests = _activeCounts[nextPub.id] ?? 0;

            final capacity = nextPub.capacity;
            final fill = capacity > 0 ? (guests / capacity) : 0.0;

            // 🔥 Farben + Text wie im PubInfoScreen
            late Color barColor;

            if (fill < 0.5) {
              barColor = Colors.greenAccent;
            } else if (fill < 0.75) {
              barColor = Colors.orangeAccent;
            } else if (fill < 1) {
              barColor = Colors.redAccent;
            } else {
              barColor = Colors.redAccent;
            }

            // ✅ Kein Check-In → nächste Kneipe zeigen
            return Column(
              children: [
                Text(
                  "🧭 Nächste Kneipe ($distance m entfernt):",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 6),

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
                        ),
                      ),
                    ).then((result) async {
                      if (!mounted) return;
                      if (result is Map && result['changed'] == true) {
                        await _maybeUpdateNextPub();
                        setState(() {});
                      }
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        nextPub.iconPath.isNotEmpty ? nextPub.iconPath : 'assets/icons/default_pub.png',
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.local_bar, color: Colors.orangeAccent, size: 30),
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
                SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fill.clamp(0, 1),
                      minHeight: 14,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "$guests / $capacity",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),

                // ✅ Check-in Button abhängig von Nähe
                ValueListenableBuilder<bool>(
                  valueListenable: SessionManager().isNearPub,
                  builder: (_, near, __) {
                    return ElevatedButton.icon(
                      icon: Icon(near ? Icons.login : Icons.location_off),
                      label: Text(near ? "Check-in starten" : "Keine Kneipe in der Nähe"),
                      onPressed: near
                          ? () => _checkInGuest(SessionManager().guestId, nextPub.id)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: near ? Colors.green : Colors.grey.shade700,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 🚐 Mobile Einheit Button bleibt unverändert
                StreamBuilder<bool>(
                  stream: _mobileAvailableStream(),
                  builder: (context, snap) {
                    final isAvail = snap.data ?? (_mobilePubCached?.isAvailable ?? false);
                    final label = !isAvail
                        ? "🚨 Einheit unterwegs..."
                        : "Mobile Einheit anfordern";

                    return ElevatedButton.icon(
                      icon: const Icon(Icons.medical_services),
                      label: Text(label),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAvail ? Colors.orangeAccent : Colors.grey.shade800,
                      ),
                      onPressed: isAvail ? _requestMobileUnit : null,
                    );
                  },
                )
              ],
            );
          },
        )
      ],
    );
  }

  Stream<bool> _mobileAvailableStream() {
    return FirebaseFirestore.instance
        .collection('pubs')
        .where('isMobileUnit', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((qs) {
      if (qs.docs.isEmpty) return false;
      final d = qs.docs.first.data();
      return (d['isAvailable'] ?? true) == true;
    });
  }


  Future<bool> _checkOutGuest(String guestId, String pubId) async {
    AchievementManager().notifyAction(AchievementEventType.checkOut, guestId, pubId: pubId);
    await ChallengeManager().evaluateProgress(SessionManager().guestId);

    print("🔁 Checkout: $pubId ($guestId)");

    final checkInActivity = await ActivityManager().getCheckInActivity(guestId, pubId: pubId);

    if (checkInActivity != null) {
      checkInActivity.timestampEnd = DateTime.now();
      await ActivityManager().updateActivity(checkInActivity);
      SessionManager().currentPubId.value = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Erfolgreich ausgecheckt!")),
      );
      await _maybeUpdateNextPub();
      if(!mounted)return true;

      setState(() {});

      return true;

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Kein aktiver Check-in gefunden.")),
      );
      return false;

    }
  }


  Future<bool> _checkInGuest(String guestId, String pubId, {bool consumeDrink = false}) async {
    final loc = _currentLocation;

    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Standort nicht verfügbar.")),
      );
      return false;
    }

    final ok = await ActivityManager().checkInGuest(
      guestId: guestId,
      pubId: pubId,
      consumeDrink: consumeDrink,
      latitude: loc.latitude,
      longitude: loc.longitude,
    );

    Pub? pub=PubManager().getPubById(pubId);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🍻 Du bist jetzt in {$pub.name}!")),
      );

      SessionManager().currentPubId.value = pubId; // ← Falls nicht gesetzt

      await _maybeUpdateNextPub(); // 🔥 neu berechnen
      if (mounted) setState(() {});
    }

    return ok;
  }

    Future<Pub?> _getNextUnvisitedPub() async {
    final openPubs = PubManager().allPubs.where((p) => p.isOpen && !p.isMobileUnit).toList();
    final pos = SessionManager().lastKnownLocation.value;

    if (pos == null || openPubs.isEmpty) return null;

    final visited = await ActivityManager().getVisitedPubIds(SessionManager().guestId);
    final unvisited = openPubs.where((p) => !visited.contains(p.id)).toList();
    if (unvisited.isEmpty) return null;

    unvisited.sort((a, b) {
      final da = LocationConfig.calculateDistance(_currentLocation!.latitude, _currentLocation!.longitude, a.latitude, a.longitude);
      final db = LocationConfig.calculateDistance(_currentLocation!.latitude, _currentLocation!.longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    return unvisited.first;
  }

  Pub? _getNextPub() {
    final openPubs = PubManager().allPubs.where((p) => p.isOpen && !p.isMobileUnit).toList();
    final pos = SessionManager().lastKnownLocation.value;

    if (pos == null || openPubs.isEmpty) return null;


    openPubs.sort((a, b) {
      final da = LocationConfig.calculateDistance(_currentLocation!.latitude, _currentLocation!.longitude, a.latitude, a.longitude);
      final db = LocationConfig.calculateDistance(_currentLocation!.latitude, _currentLocation!.longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    return openPubs.first;
  }

  void _updateSelfMarker() {
    final pos = SessionManager().lastKnownLocation.value;
    if (pos == null || _currentLocationIcon == null) return;

    final marker = Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(pos.latitude, pos.longitude),
      icon: _currentLocationIcon!,
      infoWindow: const InfoWindow(title: 'Du bist hier 🍻'),
      zIndex: 9999,
    );

    _selfMarker = marker;
    if (mounted) {
      setState(() {
        // nichts weiter – wir legen _selfMarker separat in _buildMap dazu
      });
    }
  }

  void _showAchievementPopup(Achievement achievement) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry; // 👈 Deklaration VOR dem Builder

    entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Halbtransparenter Hintergrund – Tipp: Popup mit Tap schließen
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry.remove(), // ✅ funktioniert jetzt
              child: Container(color: Colors.black54),
            ),
          ),

          // Dein Konfetti-Popup
          Center(
            child: AchievementPopup(achievement: achievement),
          ),
        ],
      ),
    );

    overlay.insert(entry);

    // Nach 4 Sekunden automatisch entfernen
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

}
