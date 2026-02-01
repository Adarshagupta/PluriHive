import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api_service.dart';

class TerritoryApiService {
  final http.Client _client;
  final AuthApiService _authService;

  TerritoryApiService({
    required AuthApiService authService,
    http.Client? client,
  })  : _authService = authService,
        _client = client ?? http.Client();

  // Capture Territories
  Future<Map<String, dynamic>> captureTerritories({
    required List<String> hexIds,
    required List<Map<String, double>> coordinates,
    List<List<Map<String, double>>>? routePoints,
    String? captureSessionId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final Map<String, dynamic> body = {
        'hexIds': hexIds,
        'coordinates': coordinates,
      };
      
      if (captureSessionId != null) {
        body['captureSessionId'] = captureSessionId;
      }

      if (routePoints != null) {
        body['routePoints'] = routePoints;
      }

      final response = await _client
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.captureTerritoriesEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.uploadTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to capture territories');
      }
    } catch (e) {
      throw Exception('Capture territories error: $e');
    }
  }

  Future<Map<String, dynamic>> captureTerritoriesPayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.captureTerritoriesEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.uploadTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to capture territories');
      }
    } catch (e) {
      throw Exception('Capture territories error: $e');
    }
  }

  // Get User Territories
  Future<List<Map<String, dynamic>>> getUserTerritories(String userId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.userTerritoriesEndpoint}/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get user territories');
      }
    } catch (e) {
      throw Exception('Get user territories error: $e');
    }
  }

  // Get All Territories (for universal map display)
  Future<List<Map<String, dynamic>>> getAllTerritories({
    int limit = 5000,
    int? offset,
  }) async {
    try {
      final offsetParam = offset != null ? '&offset=$offset' : '';
      final response = await _client
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}/territories/all?limit=$limit$offsetParam'),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ Loaded ${data.length} territories from backend');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get all territories: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Territory loading error: $e');
      throw Exception('Get all territories error: $e');
    }
  }

  // Get Nearby Territories
  Future<List<Map<String, dynamic>>> getNearbyTerritories({
    required double lat,
    required double lng,
    double radius = 1.0,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.nearbyTerritoriesEndpoint}?lat=$lat&lng=$lng&radius=$radius'),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get nearby territories');
      }
    } catch (e) {
      throw Exception('Get nearby territories error: $e');
    }
  }

  // Get Weekly Boss Territories
  Future<List<Map<String, dynamic>>> getBossTerritories({int limit = 3}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/territories/boss?limit=$limit'),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get boss territories');
      }
    } catch (e) {
      throw Exception('Get boss territories error: $e');
    }
  }

  Future<Map<String, dynamic>> updateTerritoryName({
    required String territoryId,
    required String name,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .patch(
            Uri.parse('${ApiConfig.baseUrl}/territories/$territoryId/name'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'name': name}),
          )
          .timeout(ApiConfig.defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to update territory name');
      }
    } catch (e) {
      throw Exception('Update territory name error: $e');
    }
  }
}
