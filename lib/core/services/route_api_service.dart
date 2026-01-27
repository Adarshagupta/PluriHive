import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api_service.dart';

class RouteApiService {
  final http.Client _client;
  final AuthApiService _authService;

  RouteApiService({
    required AuthApiService authService,
    http.Client? client,
  })  : _authService = authService,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> createRoute({
    required String name,
    String? description,
    required List<Map<String, double>> routePoints,
    bool isPublic = false,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.routesEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': name,
              if (description != null) 'description': description,
              'isPublic': isPublic,
              'routePoints': routePoints,
            }),
          )
          .timeout(ApiConfig.uploadTimeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to create route');
    } catch (e) {
      throw Exception('Create route error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMyRoutes() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.routesEndpoint}/my'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Failed to load routes');
    } catch (e) {
      throw Exception('Get routes error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPopularRoutes({
    required double lat,
    required double lng,
    double radiusKm = 5,
    int limit = 10,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.routesEndpoint}/popular')
          .replace(queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radiusKm': radiusKm.toString(),
        'limit': limit.toString(),
      });

      final response = await _client.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Failed to load popular routes');
    } catch (e) {
      throw Exception('Get popular routes error: $e');
    }
  }

  Future<void> recordRouteUsage(String id) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.routesEndpoint}/$id/use'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to record route usage');
      }
    } catch (e) {
      throw Exception('Record route usage error: $e');
    }
  }
}
