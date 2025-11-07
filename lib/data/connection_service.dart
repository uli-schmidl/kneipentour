import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  final StreamController<bool> _statusController = StreamController<bool>.broadcast();

  /// Stream für UI (true = online, false = offline)
  Stream<bool> get connectivityStream => _statusController.stream;

  /// Startet Live-Monitoring (keine startMonitor() mehr!)
  void initialize() {
    Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      _statusController.add(isOnline);
    });
  }
}
