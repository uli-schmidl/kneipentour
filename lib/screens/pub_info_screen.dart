import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kneipentour/data/achievement_manager.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:kneipentour/data/connection_service.dart';
import 'package:kneipentour/data/rank_manager.dart';
import 'package:kneipentour/data/session_manager.dart';
import 'package:kneipentour/models/achievement.dart';
import 'package:kneipentour/models/activity.dart';
import '../models/pub.dart';

class PubInfoScreen extends StatefulWidget {
  final Pub pub;
  final String guestId;
  final Future<bool> Function(String, String, {bool consumeDrink}) onCheckIn;
  final Future<bool> Function(String, String) onCheckOut;

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
  Timer? _cooldownTimer;
  int currentGuests = 0;


  @override
  void initState() {
    super.initState();
    _checkIfCheckedIn();
    _loadCurrentCount();
  }

  Future<void> _loadCurrentCount() async {
    currentGuests = await ActivityManager().getActiveCheckInsForPub(widget.pub.id);
    if (mounted) setState(() {});
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
    final loc = SessionManager().lastKnownLocation.value;

    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Standort konnte nicht ermittelt werden.")),
      );
      return;
    }

    final success = await ActivityManager().checkInGuest(
      guestId: widget.guestId,
      pubId: widget.pub.id,
      latitude: loc.latitude,
      longitude: loc.longitude,
    );

    if (success) {
      setState(() {
        isCheckedIn = true;
        currentCheckedInPubId = widget.pub.id;
      });
    }
  }



  void _handleCheckOut() async {
    await widget.onCheckOut(widget.guestId, widget.pub.id);
    setState(() {
      isCheckedIn = false;
      currentCheckedInPubId = '';
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
              FutureBuilder<int>(
                future: ActivityManager().getDrinkCount(guest),
                builder: (context, snapshot) {
                  final drinks = snapshot.data ?? 0;
                  final rank = RankManager().getRankForDrinks(drinks);
                  return ListTile(
                    leading: Text(rank.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(guest,
                        style: TextStyle(color: rank.color)),
                  );
                },
              ),
          ],
        );
      },
    );
  }
  void _payWithPayPal(BuildContext context, double amount, String pubId, String pubName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) => PaypalCheckoutView(
          sandboxMode: true, // später false für Livebetrieb
          clientId: "AZD6aNSsd2yDqnxFN96Mk7d0QlxEnrxagQCJMHCkwXSLbPCKATa9u3p1H5gemuUILfZ6s7HSGxEvR_dG",
          secretKey: "EMRAjQbPs7AU9lXFYoLeurb3mUbyO87PN6_dApzDlyiXjcEaMyMy2zrHYdTRDnC_11BmaDsmdT9ijrvV",
          transactions: [
            {
              "amount": {
                "total": amount.toStringAsFixed(2),
                "currency": "EUR",
                "details": {
                  "subtotal": amount.toStringAsFixed(2),
                }
              },
              "description": "Getränk in $pubName 🍺"
            }
          ],
          note: "Prost! Danke fürs Mitmachen bei der Kneipentour 🍻",
          onSuccess: (Map params) async {
            print("✅ PayPal-Zahlung erfolgreich: $params");
            Navigator.pop(context);
            await _logDrink(pubId, pubName, payment: "paypal");

            // 🔹 Drink Activity speichern
            await ActivityManager().logActivity(
              Activity(
                id: '',
                guestId: SessionManager().guestId,
                pubId: pubId,
                action: 'drink',
                timestampBegin: DateTime.now(),
                latitude: 0, // kann optional durch aktuelle Location ersetzt werden
                longitude: 0,
              ),
            );

            // 🔹 Achievement-Event auslösen
            AchievementManager().notifyAction(
              AchievementEventType.drink,
              SessionManager().guestId,
              pubId: pubId,
            );

            // 🔹 SnackBar oder Popup anzeigen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("🍻 Zahlung erfolgreich! Getränk gebucht.")),
            );
          },
          onError: (error) {
            print("❌ Zahlung fehlgeschlagen: $error");
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("⚠️ Zahlung fehlgeschlagen.")),
            );
          },
          onCancel: () {
            print("🟡 Zahlung abgebrochen");
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("💸 Zahlung abgebrochen.")),
            );
          },
        ),
      ),
    );
  }
  void _showPaymentChoiceDialog(BuildContext context, String pubId, String pubName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "Wie möchtest du bezahlen?",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Bitte wähle eine Zahlungsart für dein Getränk:",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.euro, color: Colors.orangeAccent),
              label: const Text("Barzahlung", style: TextStyle(color: Colors.orangeAccent)),
              onPressed: () async {
                Navigator.pop(context);
                await _logDrink(pubId, pubName, payment: "cash");
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.payment, color: Colors.blueAccent),
              label: const Text("PayPal", style: TextStyle(color: Colors.blueAccent)),
              onPressed: () {
                Navigator.pop(context);
                _payWithPayPal(context, 3.50, pubId, pubName); // Betrag dynamisch möglich
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logDrink(String pubId, String pubName, {String payment = "cash"}) async {
    final loc = SessionManager().lastKnownLocation.value;

    final guestId = SessionManager().guestId;

    // Default auf 0 fallback (kann später offline behandelt werden)
    final lat = loc?.latitude ?? 0;
    final lon = loc?.longitude ?? 0;

    await ActivityManager().logDrink(
      guestId: guestId,
      pubId: pubId,
      pubName: pubName,
      latitude: lat,
      longitude: lon,
      payment: payment,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payment == "cash"
              ? "🍻 Getränk registriert (Barzahlung)"
              : "🍻 Getränk registriert (PayPal)",
        ),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final capacity = widget.pub.capacity;
    final fill = capacity > 0 ? (currentGuests / capacity) : 0.0;

    String fillText;
    Color barColor;
    if (fill < 0.5) {
      barColor = Colors.greenAccent;
      fillText = "🟢 rankommen!";
    } else if (fill < 0.75) {
      barColor = Colors.orangeAccent;
      fillText = "🟠 gmidli";
    } else if (fill < 1){
      barColor = Colors.redAccent;
      fillText = "🔴 kuschelilg";
    } else {
      barColor = Colors.redAccent;
      fillText = "🔥 zerbirst";
    }
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

                  Text(
                  "Füllstand",
                  style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  ),
                  ),
                  const SizedBox(height: 8),

                  ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                  value: fill.clamp(0, 1),
                  minHeight: 14,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                  "$currentGuests / $capacity · $fillText",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

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
                        StreamBuilder<bool>(
                          stream: ConnectionService().connectivityStream,
                          builder: (context, snapshot) {
                            final isOnline = snapshot.data ?? true;

                            // ✅ Button nur anzeigen, wenn OFFLINE
                            if (isOnline) return const SizedBox.shrink();

                            return ElevatedButton.icon(
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text("QR Check-in (Offline)"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () async {
                                Navigator.pushNamed(context, "/qrCheckin");
                              },
                            );
                          },
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
                                    ? () => _showPaymentChoiceDialog(
                                      context,
                                      widget.pub.id,
                                      widget.pub.name,
                                    )
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
