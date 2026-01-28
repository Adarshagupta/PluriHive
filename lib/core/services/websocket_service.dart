import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  String? _userId;
  final List<Function(dynamic)> _pendingUserStatsListeners = [];
  final List<Function(dynamic)> _pendingTerritorySnapshotListeners = [];
  int? _lastTerritoryEventAt;

  // Initialize and connect
  void connect(String userId, {String? token}) {
    if (token == null || token.isEmpty) {
      print('⚠️ WebSocket token missing - skipping connect');
      return;
    }

    _userId = userId;

    if (_socket != null) {
      if (_socket!.connected && _userId == userId) {
        print('⚠️ WebSocket already connected');
        return;
      }
      _socket!.dispose();
      _socket = null;
    }

    _socket = IO.io(
      ApiConfig.wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(2000)
          .setTimeout(8000)
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ WebSocket connected');
      // Announce user connection
      _socket!.emit('user:connect', {'userId': userId});
      _socket!.off('user:stats:update');
      for (final listener in _pendingUserStatsListeners) {
        _socket!.on('user:stats:update', listener);
      }
      _socket!.off('territory:snapshot');
      for (final listener in _pendingTerritorySnapshotListeners) {
        _socket!.on('territory:snapshot', listener);
      }
      if (_lastTerritoryEventAt != null) {
        _socket!.emit('territory:replay', {'since': _lastTerritoryEventAt});
      }
    });

    _socket!.onDisconnect((_) {
      print('❌ WebSocket disconnected');
    });

    _socket!.onReconnect((attempt) {
      print('🔄 WebSocket reconnected (attempt $attempt)');
    });

    _socket!.onConnectError((error) {
      print('❌ WebSocket connection error: $error');
    });

    _socket!.onError((error) {
      print('❌ WebSocket error: $error');
    });

    _socket!.connect();
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

  // Ack territory events so server can track last delivered timestamp
  void emitTerritoryAck({required String eventId, required int ts}) {
    if (_socket != null && _socket!.connected) {
      _updateLastTerritoryEventAt(ts);
      _socket!.emit('territory:ack', {
        'eventId': eventId,
        'ts': ts,
      });
    } else {
      _updateLastTerritoryEventAt(ts);
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

  // Listen for territory captured (server broadcast)
  void onTerritoryCaptured(Function(dynamic) callback) {
    _socket?.on('territory:captured', callback);
  }

  void offTerritoryCaptured(Function(dynamic) callback) {
    _socket?.off('territory:captured', callback);
  }

  // Listen for territory snapshots (bulk data)
  void onTerritorySnapshot(Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.on('territory:snapshot', callback);
    } else {
      _pendingTerritorySnapshotListeners.add(callback);
    }
  }

  void offTerritorySnapshot(Function(dynamic) callback) {
    _socket?.off('territory:snapshot', callback);
    _pendingTerritorySnapshotListeners.remove(callback);
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
    _socket?.off('territory:captured');
    _socket?.off('territory:snapshot');
    _socket?.off('user:location');
    _socket?.off('leaderboard:update');
    _socket?.off('achievement:unlocked');
    _socket?.off('user:stats:update');
  }

  // Request territory snapshot around a location
  void requestTerritorySnapshot({
    required double lat,
    required double lng,
    List<double>? radiiKm,
    double? radiusKm,
    int? batchSize,
  }) {
    if (_socket == null) return;
    final payload = {
      'lat': lat,
      'lng': lng,
      if (radiiKm != null && radiiKm.isNotEmpty) 'radiiKm': radiiKm,
      if (radiusKm != null) 'radiusKm': radiusKm,
      if (batchSize != null) 'batchSize': batchSize,
    };
    _socket!.emit('territory:subscribe', payload);
  }

  void _updateLastTerritoryEventAt(int ts) {
    if (_lastTerritoryEventAt == null || ts > _lastTerritoryEventAt!) {
      _lastTerritoryEventAt = ts;
    }
  }

  bool get isConnected => _socket != null && _socket!.connected;
}
