import '../entities/user_stats.dart';

abstract class GameRepository {
  Future<UserStats> getUserStats();
  Future<void> updateStats(UserStats stats);
  Future<int> calculatePoints(double distanceKm, int territoriesCaptured);
  Future<int> calculateCalories(double distanceKm, Duration duration, double weightKg);
}
