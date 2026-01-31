import '../models/geo_types.dart';
import 'engagement_api_service.dart';

class Poi {
  final String id;
  final String name;
  final String category;
  final LatLng position;

  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'lat': position.latitude,
        'lng': position.longitude,
      };

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
    );
  }
}

class PoiMission {
  final String id;
  final DateTime createdAt;
  final List<Poi> pois;
  final Set<String> visited;
  final int rewardPoints;
  final bool completed;
  final bool rewardGranted;

  const PoiMission({
    required this.id,
    required this.createdAt,
    required this.pois,
    required this.visited,
    required this.rewardPoints,
    required this.completed,
    required this.rewardGranted,
  });

  PoiMission copyWith({
    List<Poi>? pois,
    Set<String>? visited,
    int? rewardPoints,
    bool? completed,
    bool? rewardGranted,
  }) {
    return PoiMission(
      id: id,
      createdAt: createdAt,
      pois: pois ?? this.pois,
      visited: visited ?? this.visited,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      completed: completed ?? this.completed,
      rewardGranted: rewardGranted ?? this.rewardGranted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'pois': pois.map((poi) => poi.toJson()).toList(),
        'visited': visited.toList(),
        'rewardPoints': rewardPoints,
        'completed': completed,
        'rewardGranted': rewardGranted,
      };

  factory PoiMission.fromJson(Map<String, dynamic> json) {
    return PoiMission(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
      pois: (json['pois'] as List<dynamic>)
          .map((e) => Poi.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      visited: (json['visited'] as List<dynamic>)
          .map((e) => e.toString())
          .toSet(),
      rewardPoints: json['rewardPoints'] ?? 150,
      completed: json['completed'] ?? false,
      rewardGranted: json['rewardGranted'] ?? false,
    );
  }
}

class PoiMissionProgress {
  final PoiMission mission;
  final List<Poi> newlyVisited;
  final bool completedNow;
  final bool rewardGrantedNow;

  const PoiMissionProgress({
    required this.mission,
    required this.newlyVisited,
    required this.completedNow,
    required this.rewardGrantedNow,
  });
}

class PoiMissionService {
  PoiMissionService({required EngagementApiService apiService})
      : _apiService = apiService;

  final EngagementApiService _apiService;

  static const double _visitRadiusMeters = 40.0;

  PoiMission? _mission;
  DateTime? _lastFetchedAt;

  double get visitRadiusMeters => _visitRadiusMeters;

  PoiMission? get activeMission => _mission;

  Future<void> initialize() async {}

  Future<PoiMission> ensureMission(LatLng center) async {
    if (_mission != null && _isSameDay(_mission!.createdAt, DateTime.now())) {
      if (_lastFetchedAt != null &&
          DateTime.now().difference(_lastFetchedAt!) <
              const Duration(minutes: 5)) {
        return _mission!;
      }
    }

    final data = await _apiService.getPoiMission(
      lat: center.latitude,
      lng: center.longitude,
    );
    final missionRaw = Map<String, dynamic>.from(data['mission']);
    _mission = PoiMission.fromJson(missionRaw);
    _lastFetchedAt = DateTime.now();
    return _mission!;
  }

  Future<PoiMissionProgress?> updateProgress(LatLng userLocation) async {
    if (_mission == null) return null;
    try {
      final data = await _apiService.visitPoiMission(
        lat: userLocation.latitude,
        lng: userLocation.longitude,
      );
      final missionRaw = Map<String, dynamic>.from(data['mission']);
      final mission = PoiMission.fromJson(missionRaw);
      _mission = mission;

      final newlyVisitedRaw = (data['newlyVisited'] as List<dynamic>?) ?? [];
      final newlyVisited = newlyVisitedRaw
          .map((item) => Poi.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final completedNow = data['completedNow'] == true;
      final rewardGrantedNow = data['rewardGrantedNow'] == true;

      if (newlyVisited.isEmpty && !completedNow && !rewardGrantedNow) {
        return null;
      }

      return PoiMissionProgress(
        mission: mission,
        newlyVisited: newlyVisited,
        completedNow: completedNow,
        rewardGrantedNow: rewardGrantedNow,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
