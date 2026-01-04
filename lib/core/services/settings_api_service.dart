import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api_service.dart';

class SettingsApiService {
  final http.Client _client;
  final AuthApiService _authService;

  SettingsApiService({
    http.Client? client,
    required AuthApiService authService,
  })  : _client = client ?? http.Client(),
        _authService = authService;

  // Get user settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/users/settings'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get settings');
      }
    } catch (e) {
      throw Exception('Get settings error: $e');
    }
  }

  // Update user settings
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/users/settings'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(settings),
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['settings'] ?? {};
      } else {
        throw Exception('Failed to update settings');
      }
    } catch (e) {
      throw Exception('Update settings error: $e');
    }
  }
}
