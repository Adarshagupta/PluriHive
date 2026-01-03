import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/territory.dart';

abstract class TerritoryLocalDataSource {
  Future<List<Territory>> getCapturedTerritories();
  Future<void> saveTerritories(List<Territory> territories);
  Future<void> captureTerritory(Territory territory);
  Future<bool> isTerritoryCapture(String hexId);
}

class TerritoryLocalDataSourceImpl implements TerritoryLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _territoriesKey = 'captured_territories';
  
  TerritoryLocalDataSourceImpl(this.sharedPreferences);
  
  @override
  Future<List<Territory>> getCapturedTerritories() async {
    final territoriesJson = sharedPreferences.getString(_territoriesKey);
    if (territoriesJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(territoriesJson);
    return decoded.map((json) => Territory.fromJson(json)).toList();
  }
  
  @override
  Future<void> saveTerritories(List<Territory> territories) async {
    final encoded = jsonEncode(territories.map((t) => t.toJson()).toList());
    await sharedPreferences.setString(_territoriesKey, encoded);
  }
  
  @override
  Future<void> captureTerritory(Territory territory) async {
    final territories = await getCapturedTerritories();
    
    // Check if already captured
    final index = territories.indexWhere((t) => t.hexId == territory.hexId);
    if (index != -1) {
      territories[index] = territory; // Update
    } else {
      territories.add(territory);
    }
    
    await saveTerritories(territories);
  }
  
  @override
  Future<bool> isTerritoryCapture(String hexId) async {
    final territories = await getCapturedTerritories();
    return territories.any((t) => t.hexId == hexId);
  }
}
