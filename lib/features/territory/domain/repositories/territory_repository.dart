import '../entities/territory.dart';

abstract class TerritoryRepository {
  Future<List<Territory>> getCapturedTerritories();
  Future<void> captureTerritory(Territory territory);
  Future<bool> isTerritoryCapture(String hexId);
  Future<void> saveTerritories(List<Territory> territories);
}
