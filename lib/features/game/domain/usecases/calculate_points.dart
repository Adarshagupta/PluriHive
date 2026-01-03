import '../repositories/game_repository.dart';

class CalculatePoints {
  final GameRepository repository;
  
  CalculatePoints(this.repository);
  
  Future<int> call(double distanceKm, int territoriesCaptured) {
    return repository.calculatePoints(distanceKm, territoriesCaptured);
  }
}
