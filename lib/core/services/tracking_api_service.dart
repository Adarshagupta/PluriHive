import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api_service.dart';

class TrackingApiService {
  final http.Client _client;
  final AuthApiService _authService;

  TrackingApiService({
    required AuthApiService authService,
    http.Client? client,
  })  : _authService = authService,
        _client = client ?? http.Client();

  // Save Activity
  Future<Map<String, dynamic>> saveActivity({
    required List<Map<String, dynamic>> routePoints,
    required double distanceMeters,
    required String duration,
    required double averageSpeed,
    required int steps,
    required int caloriesBurned,
    required int territoriesCaptured,
    required int pointsEarned,
    required DateTime startTime,
    required DateTime endTime,
    String? routeMapSnapshot,
    List<String>? capturedHexIds,
    String? clientId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.activitiesEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              if (clientId != null) 'clientId': clientId,
              'routePoints': routePoints,
              'distanceMeters': distanceMeters,
              'duration': duration,
              'averageSpeed': averageSpeed,
              'steps': steps,
              'caloriesBurned': caloriesBurned,
              'territoriesCaptured': territoriesCaptured,
              'pointsEarned': pointsEarned,
              'startTime': startTime.toIso8601String(),
              'endTime': endTime.toIso8601String(),
              if (routeMapSnapshot != null) 'routeMapSnapshot': routeMapSnapshot,
              if (capturedHexIds != null) 'capturedHexIds': capturedHexIds,
            }),
          )
          .timeout(ApiConfig.uploadTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to save activity');
      }
    } catch (e) {
      throw Exception('Save activity error: $e');
    }
  }

  Future<Map<String, dynamic>> saveActivityPayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.activitiesEndpoint}'),
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
        throw Exception(data['message'] ?? 'Failed to save activity');
      }
    } catch (e) {
      throw Exception('Save activity error: $e');
    }
  }

  // Get User Activities
  Future<List<Map<String, dynamic>>> getUserActivities({int limit = 50}) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.activitiesEndpoint}?limit=$limit'),
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
        throw Exception('Failed to get activities');
      }
    } catch (e) {
      throw Exception('Get activities error: $e');
    }
  }

  // Get Activity by ID
  Future<Map<String, dynamic>> getActivityById(String id) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.activitiesEndpoint}/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to get activity');
      }
    } catch (e) {
      throw Exception('Get activity error: $e');
    }
  }
}
