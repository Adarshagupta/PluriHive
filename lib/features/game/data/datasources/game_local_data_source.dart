import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_stats.dart';

abstract class GameLocalDataSource {
  Future<UserStats> getUserStats();
  Future<void> updateStats(UserStats stats);
}

class GameLocalDataSourceImpl implements GameLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _statsKey = 'user_stats';
  
  GameLocalDataSourceImpl(this.sharedPreferences);
  
  @override
  Future<UserStats> getUserStats() async {
    final statsJson = sharedPreferences.getString(_statsKey);
    if (statsJson == null) {
      return const UserStats(
        totalPoints: 0,
        level: 1,
        territoriesCaptured: 0,
        totalDistanceKm: 0.0,
        totalCaloriesBurned: 0,
        currentStreak: 0,
        longestStreak: 0,
        streakFreezes: 0,
      );
    }
    
    return UserStats.fromJson(jsonDecode(statsJson));
  }
  
  @override
  Future<void> updateStats(UserStats stats) async {
    final encoded = jsonEncode(stats.toJson());
    await sharedPreferences.setString(_statsKey, encoded);
  }
}
