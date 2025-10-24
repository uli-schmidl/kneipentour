import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/models/activity.dart';
import '../models/pub.dart';

class PubInfoScreen extends StatefulWidget {
  final Pub pub;
  final String guestId;
  final Future<void> Function(String, String, {bool consumeDrink}) onCheckIn;
  final Future<void> Function(String, String) onCheckOut;

  const PubInfoScreen({
    required this.pub,
    required this.guestId,
    required this.onCheckIn,
    required this.onCheckOut,
    super.key,
  });

  @override
  State<PubInfoScreen> createState() => _PubInfoScreenState();
}

class _PubInfoScreenState extends State<PubInfoScreen> {
  bool isCheckedIn = false;
  late String currentCheckedInPubId;

  // 🔹 neu: ValueNotifier für Cooldown
  final ValueNotifier<int> _secondsRemaining = ValueNotifier<int>(0);
  bool _drinkCooldown = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _checkIfCheckedIn();
  }

  Future<void> _checkIfCheckedIn() async {
    final activities = await ActivityManager().getGuestActivities(widget.guestId, action: 'check-in');
    final checkedInActivity = activities.firstWhere(
          (activity) => activity.pubId == widget.pub.id && activity.timestampEnd == null,
      orElse: () => Activity(
        id: '',
        guestId: '',
        pubId: '',
        action: '',
        timestampBegin: DateTime.now(),
        latitude: 0,
        longitude: 0,
      ),
    );

    if (checkedInActivity.action == 'check-in' && checkedInActivity.timestampEnd == null) {
      setState(() {
        isCheckedIn = true;
        currentCheckedInPubId = widget.pub.id;
      });
    }
  }

  void _handleCheckIn() async {
    await widget.onCheckIn(widget.guestId, widget.pub.id, consumeDrink: false);
    setState(() {
      isCheckedIn = true;
      currentCheckedInPubId = widget.pub.id;
    });
  }

  void _handleCheckOut() async {
    await widget.onCheckOut(widget.guestId, widget.pub.id);
    setState(() {
      isCheckedIn = false;
      currentCheckedInPubId = '';
    });
  }

  /// 🔹 Cooldown nur im Button über ValueNotifier steuern
  Future<void> _consumeDrink() async {
  AchievementManager().notifyAction(AchievementEventType.drink, SessionManager().guestId, pubId: widget.pub.id);

  _drinkCooldown = true;
    _secondsRemaining.value = 10;

    await ActivityManager().logActivity(
      Activity(
        id: '',
        guestId: SessionManager().guestId,
        pubId: widget.pub.id,
        action: 'drink',
        timestampBegin: DateTime.now(),
        latitude: 0,
        longitude: 0,
      ),
    );

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining.value > 1) {
        _secondsRemaining.value--;
      } else {
        _drinkCooldown = false;
        _secondsRemaining.value = 0;
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _secondsRemaining.dispose();
    super.dispose();
  }

  Stream<int> _drinksConsumedStream(String guestId, String pubId) {
    return ActivityManager()
        .streamGuestActivities(guestId)
        .map((activities) =>
    activities.where((a) => a.pubId == pubId && a.action == 'drink').length);
  }

  Widget buildGuestActivityInfo(String pubId) {
    return StreamBuilder<List<Activity>>(
      stream: ActivityManager().streamGuestActivitiesForPub(pubId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("Keine eingecheckten Gäste", style: TextStyle(color: Colors.white70));
        }

        final checkedInGuests = snapshot.data!
            .where((a) => a.pubId == pubId && a.action == 'check-in' && a.timestampEnd == null)
            .map((a) => a.guestId)
            .toSet();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🍻 Eingecheckte Gäste:",
              style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (var guest in checkedInGuests)
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white70),
                title: Text(guest, style: const TextStyle(color: Colors.white70)),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.pub.name),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.pub.iconPath.isNotEmpty
                        ? widget.pub.iconPath
                        : 'assets/icons/default_pub.png',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withOpacity(0.5)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🕓 Öffnungsstatus
                  Row(
                    children: [
                      Icon(
                        widget.pub.isOpen ? Icons.circle : Icons.cancel,
                        color: widget.pub.isOpen ? Colors.greenAccent : Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.pub.isOpen ? "Geöffnet" : "Geschlossen",
                        style: TextStyle(
                          color: widget.pub.isOpen ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    widget.pub.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(isCheckedIn ? Icons.exit_to_app : Icons.login),
                          label: Text(isCheckedIn ? "Auschecken" : "Check-in starten"),
                          onPressed: isCheckedIn ? _handleCheckOut : _handleCheckIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCheckedIn ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 🔹 Nur der Button rebuildet über ValueListenableBuilder
                        StreamBuilder<int>(
                          stream: _drinksConsumedStream(widget.guestId, widget.pub.id),
                          builder: (context, snapshot) {
                            final drinks = snapshot.data ?? 0;

                            return ValueListenableBuilder<int>(
                              valueListenable: _secondsRemaining,
                              builder: (context, seconds, _) {
                                final onCooldown = seconds > 0;

                                return ElevatedButton.icon(
                                  onPressed: (!onCooldown &&
                                      widget.pub.isOpen &&
                                      isCheckedIn)
                                      ? _consumeDrink
                                      : null,
                                  icon: const Icon(Icons.local_drink),
                                  label: Text(
                                    onCooldown
                                        ? "Nächstes Getränk in ${seconds}s"
                                        : "Getränk konsumieren ($drinks)",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: onCooldown
                                        ? Colors.grey
                                        : Colors.deepOrangeAccent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    textStyle: const TextStyle(fontSize: 16),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Eingecheckte Gäste',
                    style: TextStyle(
                      color: Colors.orangeAccent.shade200,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  buildGuestActivityInfo(widget.pub.id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
