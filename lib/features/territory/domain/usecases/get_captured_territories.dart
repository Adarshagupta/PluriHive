import '../entities/territory.dart';
import '../repositories/territory_repository.dart';

class GetCapturedTerritories {
  final TerritoryRepository repository;
  
  GetCapturedTerritories(this.repository);
  
  Future<List<Territory>> call() {
    return repository.getCapturedTerritories();
  }
}
