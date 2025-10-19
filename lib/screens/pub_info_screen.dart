import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pub.dart';
import '../models/checkin.dart';

class PubInfoScreen extends StatefulWidget {
  final Pub pub;
  final String guestId;
  final Map<String, List<CheckIn>> guestCheckIns;
  final Function(String, String, {bool consumeDrink}) onCheckIn;

  const PubInfoScreen({
    required this.pub,
    required this.guestId,
    required this.guestCheckIns,
    required this.onCheckIn,
    super.key,
  });

  @override
  State<PubInfoScreen> createState() => _PubInfoScreenState();
}

class _PubInfoScreenState extends State<PubInfoScreen> {
  bool _drinkCooldown = false;
  int _secondsRemaining = 0;
  Timer? _cooldownTimer;

  bool get isCheckedIn {
    return widget.guestCheckIns[widget.guestId]
        ?.any((c) => c.pubId == widget.pub.id) ??
        false;
  }

  int get drinksConsumed {
    final checkIns = widget.guestCheckIns[widget.guestId];
    final record = checkIns?.firstWhere(
          (c) => c.pubId == widget.pub.id,
      orElse: () => CheckIn(pubId: widget.pub.id, guestId: widget.guestId),
    );
    return record?.drinksConsumed ?? 0;
  }

  void _handleCheckIn() {
    widget.onCheckIn(widget.guestId, widget.pub.id, consumeDrink: false);
    setState(() {});
  }

  void _consumeDrink() {
    if (_drinkCooldown) return;

    widget.onCheckIn(widget.guestId, widget.pub.id, consumeDrink: true);

    setState(() {
      _drinkCooldown = true;
      _secondsRemaining = 60;
    });

    // ⏱️ Countdown-Timer starten
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() {
          _drinkCooldown = false;
          _secondsRemaining = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkIns = widget.guestCheckIns.entries
        .where((e) => e.value.any((c) => c.pubId == widget.pub.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // 🔝 AppBar mit Bild
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
                  Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),

          // 📋 Inhalt
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
                        color: widget.pub.isOpen
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.pub.isOpen ? "Geöffnet" : "Geschlossen",
                        style: TextStyle(
                          color: widget.pub.isOpen
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 📜 Beschreibung
                  Text(
                    widget.pub.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🍺 Aktionen
                  Center(
                    child: Column(
                      children: [
                        // 🟢 Check-in Button
                        ElevatedButton.icon(
                          onPressed: widget.pub.isOpen
                              ? (isCheckedIn ? null : _handleCheckIn)
                              : null,
                          icon: const Icon(Icons.login),
                          label: Text(isCheckedIn
                              ? 'Bereits eingecheckt'
                              : 'Check-in starten'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.pub.isOpen
                                ? Colors.orangeAccent
                                : Colors.grey,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 🍻 Getränk konsumieren mit Cooldown
                        ElevatedButton.icon(
                          onPressed: (!_drinkCooldown &&
                              isCheckedIn &&
                              widget.pub.isOpen)
                              ? _consumeDrink
                              : null,
                          icon: const Icon(Icons.local_drink),
                          label: Text(_drinkCooldown
                              ? "Nächstes Getränk in $_secondsRemaining s"
                              : "Getränk konsumieren ($drinksConsumed)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _drinkCooldown
                                ? Colors.grey
                                : Colors.deepOrangeAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 👥 Gästeübersicht
                  Text(
                    'Eingecheckte Gäste',
                    style: TextStyle(
                      color: Colors.orangeAccent.shade200,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (checkIns.isEmpty)
                    const Text(
                      "Noch niemand eingecheckt.",
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    ...checkIns.map((entry) {
                      final guest = entry.key;
                      final record = entry.value
                          .firstWhere((c) => c.pubId == widget.pub.id);
                      final drinkCount = record.drinksConsumed;
                      final lastTime = record.lastDrinkTime;

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          guest,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Getränke: $drinkCount | Letztes Getränk: ${lastTime != null ? DateFormat.Hm().format(lastTime) : '-'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
