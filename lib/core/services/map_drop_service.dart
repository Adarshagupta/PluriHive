import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'engagement_api_service.dart';

class MapDrop {
  final String id;
  final LatLng position;
  final DateTime expiresAt;
  final int boostMultiplier;
  final int boostSeconds;
  final double radiusMeters;

  const MapDrop({
    required this.id,
    required this.position,
    required this.expiresAt,
    required this.boostMultiplier,
    required this.boostSeconds,
    required this.radiusMeters,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': position.latitude,
        'lng': position.longitude,
        'expiresAt': expiresAt.toIso8601String(),
        'boostMultiplier': boostMultiplier,
        'boostSeconds': boostSeconds,
        'radiusMeters': radiusMeters,
      };

  factory MapDrop.fromJson(Map<String, dynamic> json) {
    return MapDrop(
      id: json['id'],
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      expiresAt: DateTime.parse(json['expiresAt']),
      boostMultiplier: json['boostMultiplier'] ?? 2,
      boostSeconds: json['boostSeconds'] ?? 120,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 45.0,
    );
  }
}

class MapDropBoost {
  final int multiplier;
  final DateTime endsAt;

  const MapDropBoost({required this.multiplier, required this.endsAt});

  bool get isActive => DateTime.now().isBefore(endsAt);

  Duration get remaining {
    final diff = endsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
        'multiplier': multiplier,
        'endsAt': endsAt.toIso8601String(),
      };

  factory MapDropBoost.fromJson(Map<String, dynamic> json) {
    return MapDropBoost(
      multiplier: json['multiplier'] ?? 2,
      endsAt: DateTime.parse(json['endsAt']),
    );
  }
}

class MapDropPickupResult {
  final List<MapDrop> pickedDrops;
  final MapDropBoost? boost;

  const MapDropPickupResult({
    required this.pickedDrops,
    required this.boost,
  });
}

class MapDropService {
  MapDropService({required EngagementApiService apiService})
      : _apiService = apiService;

  final EngagementApiService _apiService;
  final Random _random = Random();

  final List<MapDrop> _drops = [];
  MapDropBoost? _boost;

  Future<void> initialize() async {}

  List<MapDrop> get activeDrops =>
      _drops.where((drop) => !drop.isExpired).toList(growable: false);

  MapDropBoost? get activeBoost =>
      _boost != null && _boost!.isActive ? _boost : null;

  void applyBoostFromServer(MapDropBoost? boost) {
    _boost = boost;
  }

  Future<MapDropPickupResult> syncDrops(LatLng userLocation) async {
    try {
      final data = await _apiService.syncDrops(
        lat: userLocation.latitude,
        lng: userLocation.longitude,
      );
      final dropsRaw = (data['drops'] as List<dynamic>?) ?? [];
      final pickedRaw = (data['pickedDrops'] as List<dynamic>?) ?? [];

      _drops
        ..clear()
        ..addAll(
          dropsRaw.map(
            (item) => MapDrop.fromJson(Map<String, dynamic>.from(item)),
          ),
        );

      final boostRaw = data['boost'];
      _boost = boostRaw != null
          ? MapDropBoost.fromJson(Map<String, dynamic>.from(boostRaw))
          : null;

      final picked = pickedRaw
          .map((item) => MapDrop.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      return MapDropPickupResult(pickedDrops: picked, boost: _boost);
    } catch (_) {
      return const MapDropPickupResult(pickedDrops: [], boost: null);
    }
  }

  // Fallback for local-only drops (used only if backend is unavailable)
  MapDrop _generateDrop(LatLng center) {
    final bearing = _random.nextDouble() * 2 * pi;
    final distanceMeters = 200 + _random.nextInt(1200);
    final offset = _offsetByMeters(center, distanceMeters.toDouble(), bearing);
    return MapDrop(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}',
      position: offset,
      expiresAt: DateTime.now().add(const Duration(minutes: 12)),
      boostMultiplier: 2,
      boostSeconds: 120,
      radiusMeters: 45,
    );
  }

  LatLng _offsetByMeters(LatLng origin, double meters, double bearingRad) {
    final latRad = origin.latitude * (pi / 180);
    final dLat = (meters * cos(bearingRad)) / 111000.0;
    final dLng = (meters * sin(bearingRad)) / (111000.0 * cos(latRad));
    return LatLng(origin.latitude + dLat, origin.longitude + dLng);
  }
}
