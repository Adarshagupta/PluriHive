import '../entities/user_stats.dart';
import '../repositories/game_repository.dart';

class GetUserStats {
  final GameRepository repository;
  
  GetUserStats(this.repository);
  
  Future<UserStats> call() {
    return repository.getUserStats();
  }
}
