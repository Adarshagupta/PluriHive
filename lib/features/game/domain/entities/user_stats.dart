import 'package:equatable/equatable.dart';

class UserStats extends Equatable {
  final int totalPoints;
  final int level;
  final int territoriesCaptured;
  final double totalDistanceKm;
  final int totalCaloriesBurned;
  final int currentStreak;
  final int longestStreak;
  final int streakFreezes;
  
  const UserStats({
    required this.totalPoints,
    required this.level,
    required this.territoriesCaptured,
    required this.totalDistanceKm,
    required this.totalCaloriesBurned,
    required this.currentStreak,
    required this.longestStreak,
    required this.streakFreezes,
  });
  
  int get experiencePoints => totalPoints;
  int get nextLevelXP => level > 0 ? level * 1000 : 1000;
  double get progressToNextLevel {
    if (nextLevelXP <= 0) return 0.0;
    return ((experiencePoints % nextLevelXP) / nextLevelXP).clamp(0.0, 1.0);
  }
  
  @override
  List<Object?> get props => [
    totalPoints,
    level,
    territoriesCaptured,
    totalDistanceKm,
    totalCaloriesBurned,
    currentStreak,
    longestStreak,
    streakFreezes,
  ];
  
  Map<String, dynamic> toJson() => {
    'totalPoints': totalPoints,
    'level': level,
    'territoriesCaptured': territoriesCaptured,
    'totalDistanceKm': totalDistanceKm,
    'totalCaloriesBurned': totalCaloriesBurned,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'streakFreezes': streakFreezes,
  };
  
  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    totalPoints: json['totalPoints'] ?? 0,
    level: json['level'] ?? 1,
    territoriesCaptured: json['territoriesCaptured'] ?? 0,
    totalDistanceKm: json['totalDistanceKm'] ?? 0.0,
    totalCaloriesBurned: json['totalCaloriesBurned'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    longestStreak: json['longestStreak'] ?? 0,
    streakFreezes: json['streakFreezes'] ?? 0,
  );
  
  UserStats copyWith({
    int? totalPoints,
    int? level,
    int? territoriesCaptured,
    double? totalDistanceKm,
    int? totalCaloriesBurned,
    int? currentStreak,
    int? longestStreak,
    int? streakFreezes,
  }) {
    return UserStats(
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      territoriesCaptured: territoriesCaptured ?? this.territoriesCaptured,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalCaloriesBurned: totalCaloriesBurned ?? this.totalCaloriesBurned,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      streakFreezes: streakFreezes ?? this.streakFreezes,
    );
  }
}
