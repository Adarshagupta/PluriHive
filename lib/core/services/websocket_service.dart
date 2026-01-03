import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  String? _userId;

  // Initialize and connect
  void connect(String userId) {
    if (_socket != null && _socket!.connected) {
      print('⚠️ WebSocket already connected');
      return;
    }

    _userId = userId;

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('✅ WebSocket connected');
      // Announce user connection
      _socket!.emit('user:connect', {'userId': userId});
    });

    _socket!.onDisconnect((_) {
      print('❌ WebSocket disconnected');
    });

    _socket!.onConnectError((error) {
      print('❌ WebSocket connection error: $error');
    });

    _socket!.onError((error) {
      print('❌ WebSocket error: $error');
    });
  }

  // Disconnect
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _userId = null;
      print('🔌 WebSocket disconnected and disposed');
    }
  }

  // Emit territory captured
  void emitTerritoryCaptured({
    required String userId,
    required String hexId,
    required double lat,
    required double lng,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('territory:captured', {
        'userId': userId,
        'hexId': hexId,
        'lat': lat,
        'lng': lng,
      });
    }
  }

  // Emit location update
  void emitLocationUpdate({
    required String userId,
    required double lat,
    required double lng,
    required double speed,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('location:update', {
        'userId': userId,
        'lat': lat,
        'lng': lng,
        'speed': speed,
      });
    }
  }

  // Listen for territory contested
  void onTerritoryContested(Function(dynamic) callback) {
    _socket?.on('territory:contested', callback);
  }

  // Listen for user location
  void onUserLocation(Function(dynamic) callback) {
    _socket?.on('user:location', callback);
  }

  // Listen for leaderboard update
  void onLeaderboardUpdate(Function(dynamic) callback) {
    _socket?.on('leaderboard:update', callback);
  }

  // Listen for achievement unlocked
  void onAchievementUnlocked(Function(dynamic) callback) {
    _socket?.on('achievement:unlocked', callback);
  }

  // Remove all listeners
  void removeAllListeners() {
    _socket?.off('territory:contested');
    _socket?.off('user:location');
    _socket?.off('leaderboard:update');
    _socket?.off('achievement:unlocked');
  }

  bool get isConnected => _socket != null && _socket!.connected;
}
