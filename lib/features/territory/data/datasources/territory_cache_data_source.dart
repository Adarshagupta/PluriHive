import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TerritoryCacheDataSource {
  static const String _allTerritoriesKey = 'territory_cache_all';
  static const String _bossTerritoriesKey = 'territory_cache_boss';
  static const String _nearbyTerritoriesKey = 'territory_cache_nearby';

  final SharedPreferences sharedPreferences;

  TerritoryCacheDataSource(this.sharedPreferences);

  Future<void> saveAllTerritories(List<Map<String, dynamic>> territories) async {
    final encoded = jsonEncode(territories);
    await sharedPreferences.setString(_allTerritoriesKey, encoded);
  }

  Future<List<Map<String, dynamic>>> getAllTerritories() async {
    final cached = sharedPreferences.getString(_allTerritoriesKey);
    if (cached == null) return [];
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveBossTerritories(List<Map<String, dynamic>> territories) async {
    final encoded = jsonEncode(territories);
    await sharedPreferences.setString(_bossTerritoriesKey, encoded);
  }

  Future<List<Map<String, dynamic>>> getBossTerritories() async {
    final cached = sharedPreferences.getString(_bossTerritoriesKey);
    if (cached == null) return [];
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveNearbyTerritories(
    List<Map<String, dynamic>> territories,
  ) async {
    final encoded = jsonEncode(territories);
    await sharedPreferences.setString(_nearbyTerritoriesKey, encoded);
  }

  Future<List<Map<String, dynamic>>> getNearbyTerritories() async {
    final cached = sharedPreferences.getString(_nearbyTerritoriesKey);
    if (cached == null) return [];
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
