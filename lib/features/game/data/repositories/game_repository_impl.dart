import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/game_repository.dart';
import '../datasources/game_local_data_source.dart';

class GameRepositoryImpl implements GameRepository {
  final GameLocalDataSource localDataSource;
  
  GameRepositoryImpl(this.localDataSource);
  
  @override
  Future<UserStats> getUserStats() {
    return localDataSource.getUserStats();
  }
  
  @override
  Future<void> updateStats(UserStats stats) {
    return localDataSource.updateStats(stats);
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
