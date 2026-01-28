import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/territory/data/datasources/territory_cache_data_source.dart';
import 'auth_api_service.dart';
import 'territory_api_service.dart';
import 'websocket_service.dart';

class TerritoryPrefetchService {
  TerritoryPrefetchService({
    required WebSocketService webSocketService,
    required AuthApiService authApiService,
    required TerritoryApiService territoryApiService,
    required SharedPreferences prefs,
  })  : _webSocketService = webSocketService,
        _authApiService = authApiService,
        _territoryApiService = territoryApiService,
        _cache = TerritoryCacheDataSource(prefs);

  final WebSocketService _webSocketService;
  final AuthApiService _authApiService;
  final TerritoryApiService _territoryApiService;
  final TerritoryCacheDataSource _cache;

  final List<double> _radiiKm = [20, 35, 50];
  final Duration _cooldown = const Duration(seconds: 30);
  DateTime? _lastPrefetchAt;
  DateTime? _lastSnapshotAt;
  bool _inFlight = false;
  bool _listening = false;
  Timer? _fallbackTimer;

  Future<void> prefetchAroundUser() async {
    if (_inFlight) return;
    if (_lastPrefetchAt != null &&
        DateTime.now().difference(_lastPrefetchAt!) < _cooldown) {
      return;
    }

    _inFlight = true;
    _lastPrefetchAt = DateTime.now();

    try {
      final token = await _authApiService.getToken();
      final userId = await _authApiService.getUserId();
      if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _ensureSnapshotListener();
      _webSocketService.connect(userId, token: token);
      _lastSnapshotAt = null;

      final connected = await _waitForWebSocketConnected();
      var usedHttpFallback = false;
      if (connected) {
        _webSocketService.requestTerritorySnapshot(
          lat: position.latitude,
          lng: position.longitude,
          radiiKm: _radiiKm,
          batchSize: 450,
        );
      } else {
        usedHttpFallback = true;
        await _prefetchViaHttp(position.latitude, position.longitude);
      }

      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(const Duration(seconds: 6), () async {
        if (usedHttpFallback) return;
        final lastSnapshot = _lastSnapshotAt;
        if (lastSnapshot != null &&
            DateTime.now().difference(lastSnapshot) <
                const Duration(seconds: 4)) {
          return;
        }
        await _prefetchViaHttp(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Territory prefetch failed: $e');
    } finally {
      _inFlight = false;
    }
  }

  void dispose() {
    _fallbackTimer?.cancel();
    if (_listening) {
      _webSocketService.offTerritorySnapshot(_handleSnapshot);
      _listening = false;
    }
  }

  void _ensureSnapshotListener() {
    if (_listening) return;
    _listening = true;
    _webSocketService.onTerritorySnapshot(_handleSnapshot);
  }

  Future<void> _prefetchViaHttp(double lat, double lng) async {
    try {
      for (final radius in _radiiKm) {
        final territories = await _territoryApiService.getNearbyTerritories(
          lat: lat,
          lng: lng,
          radius: radius,
        );
        await _mergeAndCache(territories);
      }
    } catch (e) {
      print('Territory HTTP prefetch failed: $e');
    }
  }

  Future<void> _handleSnapshot(dynamic payload) async {
    final territories = _extractTerritories(payload);
    if (territories.isEmpty) return;
    _lastSnapshotAt = DateTime.now();
    await _mergeAndCache(territories);
  }

  List<Map<String, dynamic>> _extractTerritories(dynamic payload) {
    dynamic rawTerritories = payload;
    if (payload is Map && payload['territories'] is List) {
      rawTerritories = payload['territories'];
    }

    final List<Map<String, dynamic>> territories = [];
    if (rawTerritories is List) {
      for (final item in rawTerritories) {
        if (item is Map) {
          territories.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (rawTerritories is Map) {
      territories.add(Map<String, dynamic>.from(rawTerritories));
    }
    return territories;
  }

  Future<void> _mergeAndCache(List<Map<String, dynamic>> incoming) async {
    if (incoming.isEmpty) return;
    final cached = await _cache.getNearbyTerritories();
    final merged = <String, Map<String, dynamic>>{};
    for (final territory in cached) {
      final hexId = territory['hexId']?.toString();
      if (hexId != null && hexId.isNotEmpty) {
        merged[hexId] = territory;
      }
    }
    for (final territory in incoming) {
      final hexId = territory['hexId']?.toString();
      if (hexId != null && hexId.isNotEmpty) {
        merged[hexId] = territory;
      }
    }
    await _cache.saveNearbyTerritories(merged.values.toList());
  }

  Future<bool> _waitForWebSocketConnected({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_webSocketService.isConnected) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (_webSocketService.isConnected) return true;
    }
    return false;
  }
}
