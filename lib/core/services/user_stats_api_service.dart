import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_api_service.dart';

class UserStatsApiService {
  final AuthApiService authService;
  final http.Client client;
  final String baseUrl = 'http://10.1.80.22:3000';

  UserStatsApiService({
    required this.authService,
    required this.client,
  });

  Future<Map<String, dynamic>> getUserStats() async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception('No auth token available');
    }

    final response = await client.get(
      Uri.parse('$baseUrl/users/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch user stats: ${response.statusCode}');
    }
  }
}
