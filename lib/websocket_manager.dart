import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketManager {
  IOWebSocketChannel? _channel;
  bool _isConnected = false;
  Function(String)? onMessageReceived;

  String _ipAddress = '192.168.4.1';

  // StreamController to notify connection status changes
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Reconnection settings
  final int _reconnectInterval = 5; // Reconnect every 5 seconds
  Timer? _reconnectTimer;

  WebSocketManager({this.onMessageReceived}) {
    loadIPAddress(); // Load stored IP on initialization
  }

  /// Loads stored IP address from SharedPreferences
  Future<void> loadIPAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _ipAddress = prefs.getString('websocket_ip') ?? '192.168.4.1';
  }

  /// Returns the current WebSocket connection status
  bool get isConnected => _isConnected;

  /// Returns the current IP address
  String get ipAddress => _ipAddress;

  /// Sets a new IP address, saves it, and reconnects
  Future<void> setIPAddress(String newIp) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('websocket_ip', newIp);
    _ipAddress = newIp;
    disconnect();
    connect(); // Reconnect with new IP
  }

  /// Establishes WebSocket connection
  void connect() {
    try {
      _channel = IOWebSocketChannel.connect('ws://$_ipAddress/ws');
      _isConnected = true;
      _connectionStatusController.add(_isConnected); // Notify listeners

      _channel!.stream.listen(
            (message) {
          if (onMessageReceived != null) {
            onMessageReceived!(message);
          }
        },
        onDone: () {
          print("WebSocket connection closed. Attempting to reconnect...");
          _isConnected = false;
          _connectionStatusController.add(_isConnected);
          _scheduleReconnect();
        },
        onError: (error) {
          print("WebSocket Error: $error. Attempting to reconnect...");
          _isConnected = false;
          _connectionStatusController.add(_isConnected);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      print("WebSocket Connection Failed: $e. Attempting to reconnect...");
      _isConnected = false;
      _connectionStatusController.add(_isConnected);
      _scheduleReconnect();
    }
  }

  /// Schedules a reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectTimer == null || !_reconnectTimer!.isActive) {
      _reconnectTimer = Timer(Duration(seconds: _reconnectInterval), () {
        connect();
      });
    }
  }

  /// Sends a message via WebSocket
  void sendMessage(String message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(message);
    } else {
      print("WebSocket is not connected. Message not sent: $message");
      _scheduleReconnect(); // Attempt reconnection if not connected
    }
  }

  /// Closes WebSocket connection
  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
    _connectionStatusController.add(_isConnected);
    _reconnectTimer?.cancel(); // Stop any scheduled reconnection attempts
  }
}
