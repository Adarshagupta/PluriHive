import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api_service.dart';

class EngagementApiService {
  final http.Client _client;
  final AuthApiService _authService;

  EngagementApiService({
    required AuthApiService authService,
    http.Client? client,
  })  : _authService = authService,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> syncDrops({
    required double lat,
    required double lng,
  }) async {
    return _post(
      ApiConfig.dropsSyncEndpoint,
      {'lat': lat, 'lng': lng},
    );
  }

  Future<Map<String, dynamic>> getPoiMission({
    required double lat,
    required double lng,
  }) async {
    return _get(
      '${ApiConfig.poiMissionEndpoint}?lat=$lat&lng=$lng',
    );
  }

  Future<Map<String, dynamic>> visitPoiMission({
    required double lat,
    required double lng,
  }) async {
    return _post(
      ApiConfig.poiMissionVisitEndpoint,
      {'lat': lat, 'lng': lng},
    );
  }

  Future<Map<String, dynamic>> getRewards() async {
    return _get(ApiConfig.rewardsEndpoint);
  }

  Future<Map<String, dynamic>> unlockReward(String rewardId) async {
    return _post(ApiConfig.rewardsUnlockEndpoint, {'rewardId': rewardId});
  }

  Future<Map<String, dynamic>> selectReward(String rewardId) async {
    return _post(ApiConfig.rewardsSelectEndpoint, {'rewardId': rewardId});
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(ApiConfig.defaultTimeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(data['message'] ?? 'Request failed');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.defaultTimeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(data['message'] ?? 'Request failed');
  }
}
