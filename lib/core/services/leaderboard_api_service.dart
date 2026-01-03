import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class LeaderboardApiService {
  final http.Client _client;

  LeaderboardApiService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  // Get Global Leaderboard
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({int limit = 50}) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.leaderboardEndpoint}?limit=$limit'),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get leaderboard');
      }
    } catch (e) {
      throw Exception('Get leaderboard error: $e');
    }
  }
}
