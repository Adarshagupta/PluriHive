import '../entities/territory.dart';
import '../repositories/territory_repository.dart';

class CaptureTerritory {
  final TerritoryRepository repository;
  
  CaptureTerritory(this.repository);
  
  Future<void> call(Territory territory) {
    return repository.captureTerritory(territory);
  }
}
