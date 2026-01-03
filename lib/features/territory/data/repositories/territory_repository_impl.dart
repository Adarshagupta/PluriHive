import '../../domain/entities/territory.dart';
import '../../domain/repositories/territory_repository.dart';
import '../datasources/territory_local_data_source.dart';

class TerritoryRepositoryImpl implements TerritoryRepository {
  final TerritoryLocalDataSource localDataSource;
  
  TerritoryRepositoryImpl(this.localDataSource);
  
  @override
  Future<List<Territory>> getCapturedTerritories() {
    return localDataSource.getCapturedTerritories();
  }
  
  @override
  Future<void> captureTerritory(Territory territory) {
    return localDataSource.captureTerritory(territory);
  }
  
  @override
  Future<bool> isTerritoryCapture(String hexId) {
    return localDataSource.isTerritoryCapture(hexId);
  }
  
  @override
  Future<void> saveTerritories(List<Territory> territories) {
    return localDataSource.saveTerritories(territories);
  }
}
