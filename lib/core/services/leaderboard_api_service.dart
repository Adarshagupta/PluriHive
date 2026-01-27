import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class LeaderboardApiService {
  final http.Client _client;

  LeaderboardApiService({http.Client? client})
      : _client = client ?? http.Client();

  /// Get global leaderboard
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard(
      {int limit = 50}) async {
    try {
      final uri =
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.leaderboardEndpoint}')
              .replace(queryParameters: {'limit': limit.toString()});

      final response = await _client.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Leaderboard API error: $e');
    }
  }

  /// Get weekly leaderboard
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard(
      {int limit = 50}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/leaderboard/weekly')
          .replace(queryParameters: {'limit': limit.toString()});

      final response = await _client.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to load weekly leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Weekly leaderboard API error: $e');
    }
  }

  /// Get monthly leaderboard
  Future<List<Map<String, dynamic>>> getMonthlyLeaderboard(
      {int limit = 75}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/leaderboard/monthly')
          .replace(queryParameters: {'limit': limit.toString()});

      final response = await _client.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to load monthly leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Monthly leaderboard API error: $e');
    }
  }

  /// Get user rank
  Future<Map<String, dynamic>> getUserRank(String userId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/leaderboard/rank')
          .replace(queryParameters: {'userId': userId});

      final response = await _client.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get user rank: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('User rank API error: $e');
    }
  }

  /// Search users
  Future<List<Map<String, dynamic>>> searchUsers(String query,
      {int limit = 20}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/leaderboard/search')
          .replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });

      final response = await _client.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to search users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Search API error: $e');
    }
  }

  /// Get leaderboard statistics
  Future<Map<String, dynamic>> getLeaderboardStats() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/leaderboard/stats');

      final response = await _client.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Stats API error: $e');
    }
  }
}
