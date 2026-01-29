import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class LegalApiService {
  final http.Client _client;

  LegalApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> getPrivacyPolicy() {
    return _fetchDoc('privacy');
  }

  Future<Map<String, dynamic>> getTerms() {
    return _fetchDoc('terms');
  }

  Future<Map<String, dynamic>> getDeleteAccount() {
    return _fetchDoc('delete-account');
  }

  Future<Map<String, dynamic>> getDataUsage() {
    return _fetchDoc('data-usage');
  }

  Future<Map<String, dynamic>> _fetchDoc(String type) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/legal/$type');
    final response = await _client.get(uri, headers: {
      'Content-Type': 'application/json',
    }).timeout(ApiConfig.defaultTimeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load legal document: ${response.statusCode}');
  }
}
