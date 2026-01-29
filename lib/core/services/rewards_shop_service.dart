import 'package:flutter/material.dart';
import 'engagement_api_service.dart';

enum RewardType { marker, badge }

class RewardItem {
  final String id;
  final String name;
  final RewardType type;
  final int cost;
  final String description;
  final Color color;
  final IconData icon;

  const RewardItem({
    required this.id,
    required this.name,
    required this.type,
    required this.cost,
    required this.description,
    required this.color,
    required this.icon,
  });
}

class RewardsShopService {
  RewardsShopService({required EngagementApiService apiService})
      : _apiService = apiService;

  final EngagementApiService _apiService;

  final List<RewardItem> _catalog = const [
    RewardItem(
      id: 'marker_azure',
      name: 'Azure Ring',
      type: RewardType.marker,
      cost: 0,
      description: 'Classic blue glow around your avatar.',
      color: Color(0xFF38BDF8),
      icon: Icons.blur_circular,
    ),
    RewardItem(
      id: 'marker_ember',
      name: 'Ember Ring',
      type: RewardType.marker,
      cost: 250,
      description: 'Warm ember halo for heat seekers.',
      color: Color(0xFFF97316),
      icon: Icons.local_fire_department,
    ),
    RewardItem(
      id: 'marker_lush',
      name: 'Lush Ring',
      type: RewardType.marker,
      cost: 450,
      description: 'Fresh green glow for daily grinders.',
      color: Color(0xFF22C55E),
      icon: Icons.eco,
    ),
    RewardItem(
      id: 'marker_pulse',
      name: 'Pulse Ring',
      type: RewardType.marker,
      cost: 700,
      description: 'Electric purple ring for night missions.',
      color: Color(0xFF8B5CF6),
      icon: Icons.bolt,
    ),
    RewardItem(
      id: 'badge_trail',
      name: 'Trail Rookie',
      type: RewardType.badge,
      cost: 120,
      description: 'First missions completed badge.',
      color: Color(0xFF0EA5E9),
      icon: Icons.flag,
    ),
    RewardItem(
      id: 'badge_drop',
      name: 'Drop Hunter',
      type: RewardType.badge,
      cost: 300,
      description: 'Collect 5 power drops streak.',
      color: Color(0xFFFACC15),
      icon: Icons.bolt,
    ),
    RewardItem(
      id: 'badge_conquer',
      name: 'Territory Conqueror',
      type: RewardType.badge,
      cost: 600,
      description: 'Hold down the map with style.',
      color: Color(0xFFFB7185),
      icon: Icons.shield,
    ),
  ];

  final Set<String> _unlocked = {};
  String? _selectedMarker;
  String? _selectedBadge;
  int _spentPoints = 0;

  Future<void> initialize() async {
    try {
      final data = await _apiService.getRewards();
      _applyServerState(data);
    } catch (_) {
      // keep defaults on failure
      _applyDefaults();
    }
  }

  List<RewardItem> get markerItems =>
      _catalog.where((item) => item.type == RewardType.marker).toList();

  List<RewardItem> get badgeItems =>
      _catalog.where((item) => item.type == RewardType.badge).toList();

  bool isUnlocked(String id) => _unlocked.contains(id);

  String? get selectedMarkerId => _selectedMarker;

  String? get selectedBadgeId => _selectedBadge;

  RewardItem? get selectedMarkerItem {
    final markers = markerItems;
    if (markers.isEmpty) return null;
    final id = _selectedMarker;
    return markers.firstWhere(
      (item) => item.id == id,
      orElse: () => markers.first,
    );
  }

  RewardItem? get selectedBadgeItem {
    final badges = badgeItems;
    if (badges.isEmpty) return null;
    final id = _selectedBadge;
    return badges.firstWhere(
      (item) => item.id == id,
      orElse: () => badges.first,
    );
  }

  Color? get selectedMarkerColor => selectedMarkerItem?.color;

  int get spentPoints => _spentPoints;

  int availablePoints(int totalPoints) {
    final available = totalPoints - _spentPoints;
    return available < 0 ? 0 : available;
  }

  Future<bool> unlock(RewardItem item, int currentPoints) async {
    if (isUnlocked(item.id)) return true;
    final available = availablePoints(currentPoints);
    if (available < item.cost) return false;
    try {
      final data = await _apiService.unlockReward(item.id);
      _applyServerState(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> selectMarker(String id) async {
    if (!isUnlocked(id)) return;
    try {
      final data = await _apiService.selectReward(id);
      _applyServerState(data);
    } catch (_) {}
  }

  Future<void> selectBadge(String id) async {
    if (!isUnlocked(id)) return;
    try {
      final data = await _apiService.selectReward(id);
      _applyServerState(data);
    } catch (_) {}
  }

  void _applyServerState(Map<String, dynamic> data) {
    final unlockedIds = (data['unlockedIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    _unlocked
      ..clear()
      ..addAll(unlockedIds);
    _applyDefaults();

    _selectedMarker = data['selectedMarkerId']?.toString();
    _selectedBadge = data['selectedBadgeId']?.toString();
    _spentPoints = (data['spentPoints'] as num?)?.toInt() ?? 0;

    final markerDefaults = markerItems;
    final badgeDefaults = badgeItems;
    if (_selectedMarker == null && markerDefaults.isNotEmpty) {
      _selectedMarker = markerDefaults.first.id;
    }
    if (_selectedBadge == null && badgeDefaults.isNotEmpty) {
      _selectedBadge = badgeDefaults.first.id;
    }
  }

  void _applyDefaults() {
    for (final item in _catalog.where((item) => item.cost == 0)) {
      _unlocked.add(item.id);
    }
  }
}
