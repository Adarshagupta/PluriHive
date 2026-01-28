import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api_service.dart';

class UserProfileApiService {
  final AuthApiService authService;
  final http.Client client;

  UserProfileApiService({
    required this.authService,
    required this.client,
  });

  Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await client.get(
      Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to load user profile');
  }
}
