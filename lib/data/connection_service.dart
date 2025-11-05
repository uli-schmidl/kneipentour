import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _controller.stream;

  void startMonitor() {
    Connectivity().onConnectivityChanged.listen((status) {
      final connected = status != ConnectivityResult.none;
      _controller.add(connected);
    });
  }
}
