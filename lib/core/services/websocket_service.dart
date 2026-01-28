import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  String? _userId;
  final List<Function(dynamic)> _pendingUserStatsListeners = [];

  // Initialize and connect
  void connect(String userId, {String? token}) {
    if (_socket != null && _socket!.connected) {
      print('⚠️ WebSocket already connected');
      return;
    }

    if (token == null || token.isEmpty) {
      print('⚠️ WebSocket token missing - skipping connect');
      return;
    }

    _userId = userId;

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('✅ WebSocket connected');
      // Announce user connection
      _socket!.emit('user:connect', {'userId': userId});
      _socket!.off('user:stats:update');
      for (final listener in _pendingUserStatsListeners) {
        _socket!.on('user:stats:update', listener);
      }
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

  void offUserLocation(Function(dynamic) callback) {
    _socket?.off('user:location', callback);
  }

  // Listen for leaderboard update
  void onLeaderboardUpdate(Function(dynamic) callback) {
    _socket?.on('leaderboard:update', callback);
  }

  // Listen for achievement unlocked
  void onAchievementUnlocked(Function(dynamic) callback) {
    _socket?.on('achievement:unlocked', callback);
  }

  // Listen for user stats update
  void onUserStatsUpdate(Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.on('user:stats:update', callback);
    } else {
      _pendingUserStatsListeners.add(callback);
    }
  }

  // Remove user stats update listener
  void offUserStatsUpdate(Function(dynamic) callback) {
    _socket?.off('user:stats:update', callback);
    _pendingUserStatsListeners.remove(callback);
  }

  // Remove all listeners
  void removeAllListeners() {
    _socket?.off('territory:contested');
    _socket?.off('user:location');
    _socket?.off('leaderboard:update');
    _socket?.off('achievement:unlocked');
    _socket?.off('user:stats:update');
  }

  bool get isConnected => _socket != null && _socket!.connected;
}
