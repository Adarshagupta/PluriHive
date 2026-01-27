import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/game_repository.dart';
import '../../../../core/services/auth_api_service.dart';

class GameRepositoryImpl implements GameRepository {
  final AuthApiService authApiService;
  
  GameRepositoryImpl(this.authApiService);
  
  @override
  Future<UserStats> getUserStats() async {
    // Always fetch from backend - no local storage
    try {
      final userData = await authApiService.getCurrentUser();
      return UserStats(
        totalPoints: userData['totalPoints'] is int 
            ? userData['totalPoints'] 
            : (userData['totalPoints'] as num?)?.toInt() ?? 0,
        level: userData['level'] is int 
            ? userData['level'] 
            : (userData['level'] as num?)?.toInt() ?? 1,
        totalDistanceKm: userData['totalDistanceKm'] is String
            ? double.parse(userData['totalDistanceKm'])
            : (userData['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
        totalCaloriesBurned: 0,
        territoriesCaptured: userData['totalTerritoriesCaptured'] is int
            ? userData['totalTerritoriesCaptured']
            : (userData['totalTerritoriesCaptured'] as num?)?.toInt() ?? 0,
        currentStreak: userData['currentStreak'] is int
            ? userData['currentStreak']
            : (userData['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: userData['longestStreak'] is int
            ? userData['longestStreak']
            : (userData['longestStreak'] as num?)?.toInt() ?? 0,
        streakFreezes: userData['streakFreezes'] is int
            ? userData['streakFreezes']
            : (userData['streakFreezes'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw Exception('Failed to fetch user stats from backend: $e');
    }
  }
  
  @override
  Future<void> updateStats(UserStats stats) async {
    // Stats are automatically updated by backend when activities/territories are saved
    // No need to manually update - this is a no-op
    // The backend updates stats when:
    // 1. Activity is saved
    // 2. Territory is captured
    return Future.value();
  }
  
  @override
  Future<int> calculatePoints(double distanceKm, int territoriesCaptured) async {
    // 100 points per km
    final distancePoints = (distanceKm * 100).round();
    
    // 50 points per territory
    final territoryPoints = territoriesCaptured * 50;
    
    return distancePoints + territoryPoints;
  }
  
  @override
  Future<int> calculateCalories(double distanceKm, Duration duration, double weightKg) async {
    // MET value for running (approximate based on speed)
    final speedKmH = distanceKm / (duration.inSeconds / 3600.0);
    double met;
    
    if (speedKmH < 6) {
      met = 6.0; // Walking
    } else if (speedKmH < 8) {
      met = 8.3; // Light jogging
    } else if (speedKmH < 10) {
      met = 10.0; // Moderate running
    } else {
      met = 12.0; // Fast running
    }
    
    // Calories = MET × weight (kg) × duration (hours)
    final durationHours = duration.inSeconds / 3600.0;
    final calories = met * weightKg * durationHours;
    
    return calories.round();
  }
}
