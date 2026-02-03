import 'engagement_api_service.dart';

class Mission {
  final String id;
  final String period;
  final String type;
  final int goal;
  final int progress;
  final int rewardPoints;
  final DateTime periodStart;
  final DateTime? completedAt;
  final DateTime? rewardGrantedAt;

  const Mission({
    required this.id,
    required this.period,
    required this.type,
    required this.goal,
    required this.progress,
    required this.rewardPoints,
    required this.periodStart,
    this.completedAt,
    this.rewardGrantedAt,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id']?.toString() ?? '',
      period: json['period']?.toString() ?? 'daily',
      type: json['type']?.toString() ?? '',
      goal: (json['goal'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      periodStart: DateTime.parse(json['periodStart']),
      completedAt:
          json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      rewardGrantedAt: json['rewardGrantedAt'] != null
          ? DateTime.parse(json['rewardGrantedAt'])
          : null,
    );
  }
}

class MissionsService {
  MissionsService({required EngagementApiService apiService})
      : _apiService = apiService;

  final EngagementApiService _apiService;

  Future<List<Mission>> getDailyMissions() async {
    final data = await _apiService.getDailyMissions();
    final raw = (data['missions'] as List<dynamic>? ?? []);
    return raw
        .map((item) => Mission.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Mission>> getWeeklyMissions() async {
    final data = await _apiService.getWeeklyMissions();
    final raw = (data['missions'] as List<dynamic>? ?? []);
    return raw
        .map((item) => Mission.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
