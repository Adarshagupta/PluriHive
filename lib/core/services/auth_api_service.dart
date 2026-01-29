import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthApiService {
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences? _prefs;
  
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  AuthApiService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefs = prefs;

  // Sign Up
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('📝 Attempting sign up to: ${ApiConfig.baseUrl}${ApiConfig.signUpEndpoint}');
      print('📧 Email: $email, Name: $name');
      
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.signUpEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'name': name,
            }),
          )
          .timeout(ApiConfig.defaultTimeout);

      print('📡 Sign up response status: ${response.statusCode}');
      print('📡 Sign up response received');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Store token and user ID in secure storage
        await _secureStorage.write(key: _tokenKey, value: data['access_token']);
        await _secureStorage.write(key: _userIdKey, value: data['user']['id']);
        
        // Backup to SharedPreferences for reliability
        if (_prefs != null) {
          await _prefs!.setString(_tokenKey, data['access_token']);
          await _prefs!.setString(_userIdKey, data['user']['id']);
        }
        
        print('✅ Sign up successful! Token saved.');
        return data;
      } else {
        final errorMsg = data['message'] ?? 'Sign up failed';
        print('❌ Sign up failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } on TimeoutException {
      print('⏱️ Sign up timeout - backend may not be running');
      throw Exception('Connection timeout. Please check if backend is running on ${ApiConfig.baseUrl}');
    } catch (e) {
      print('❌ Sign up error: $e');
      throw Exception('Sign up error: $e');
    }
  }

  // Sign In
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Attempting sign in to: ${ApiConfig.baseUrl}${ApiConfig.signInEndpoint}');
      print('📧 Email: $email');
      
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.signInEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(ApiConfig.defaultTimeout);

      print('📡 Sign in response status: ${response.statusCode}');
      print('📡 Sign in response received');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['access_token'];
        final userId = data['user']['id'];
        print('💾 SignIn: Received token and userId: $userId');
        
        // Store token and user ID in secure storage
        await _secureStorage.write(key: _tokenKey, value: token);
        print('💾 SignIn: Token saved to secure storage');
        await _secureStorage.write(key: _userIdKey, value: userId);
        print('💾 SignIn: UserId saved to secure storage');
        
        // Backup to SharedPreferences for reliability
        if (_prefs != null) {
          await _prefs!.setString(_tokenKey, token);
          print('💾 SignIn: Token saved to SharedPreferences');
          await _prefs!.setString(_userIdKey, userId);
          print('💾 SignIn: UserId saved to SharedPreferences');
        } else {
          print('⚠️ SignIn: SharedPreferences is NULL - backup not saved!');
        }
        
        print('✅ Sign in successful! Token saved.');
        return data;
      } else {
        final errorMsg = data['message'] ?? 'Sign in failed';
        print('❌ Sign in failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } on TimeoutException {
      print('⏱️ Sign in timeout - backend may not be running');
      throw Exception('Connection timeout. Please check if backend is running on ${ApiConfig.baseUrl}');
    } catch (e) {
      print('❌ Sign in error: $e');
      throw Exception('Sign in error: $e');
    }
  }

  // Get Current User
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getMeEndpoint}'),
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
        throw Exception(data['message'] ?? 'Failed to get user');
      }
    } catch (e) {
      throw Exception('Get user error: $e');
    }
  }

  // Update Profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.userProfileEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(updates),
          )
          .timeout(ApiConfig.defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Update profile error: $e');
    }
  }

  // Complete Onboarding
  Future<Map<String, dynamic>> completeOnboarding() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/users/complete-onboarding'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ Onboarding completed successfully');
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to complete onboarding');
      }
    } catch (e) {
      print('❌ Complete onboarding error: $e');
      throw Exception('Complete onboarding error: $e');
    }
  }

  // Sign In with Google
  Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
  }) async {
    try {
      print('🔵 Attempting Google sign in to: ${ApiConfig.baseUrl}/auth/google');
      
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': idToken,
            }),
          )
          .timeout(ApiConfig.defaultTimeout);

      print('📡 Google sign in response status: ${response.statusCode}');
      print('📡 Google sign in response received');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['access_token'];
        final userId = data['user']['id'];
        print('💾 Google SignIn: About to save token and userId: $userId');
        
        // Store token and user ID in secure storage
        await _secureStorage.write(key: _tokenKey, value: token);
        print('💾 Google SignIn: Token saved to secure storage');
        await _secureStorage.write(key: _userIdKey, value: userId);
        print('💾 Google SignIn: UserId saved to secure storage');
        
        // Backup to SharedPreferences for reliability
        if (_prefs != null) {
          await _prefs!.setString(_tokenKey, token);
          print('💾 Google SignIn: Token saved to SharedPreferences');
          await _prefs!.setString(_userIdKey, userId);
          print('💾 Google SignIn: UserId saved to SharedPreferences');
        } else {
          print('⚠️ Google SignIn: SharedPreferences is NULL - backup not saved!');
        }
        
        print('✅ Google sign in successful! Token saved.');
        return data;
      } else {
        final errorMsg = data['message'] ?? 'Google sign in failed';
        print('❌ Google sign in failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } on TimeoutException {
      print('⏱️ Google sign in timeout - backend may not be running');
      throw Exception('Connection timeout. Please check if backend is running on ${ApiConfig.baseUrl}');
    } catch (e) {
      print('❌ Google sign in error: $e');
      throw Exception('Google sign in error: $e');
    }
  }


  // Token Management
  Future<String?> getToken() async {
    print('🔑 getToken: Reading from secure storage...');
    // Try secure storage first
    var token = await _secureStorage.read(key: _tokenKey);
    print('🔑 getToken: Secure storage token = ${token != null ? "EXISTS" : "NULL"}');
    
    // Fallback to SharedPreferences if secure storage fails
    if ((token == null || token.isEmpty) && _prefs != null) {
      print('🔑 getToken: Trying SharedPreferences fallback...');
      token = _prefs!.getString(_tokenKey);
      print('🔑 getToken: SharedPreferences token = ${token != null ? "EXISTS" : "NULL"}');
      
      // Restore to secure storage if found in SharedPreferences
      if (token != null && token.isNotEmpty) {
        print('🔑 getToken: Restoring token to secure storage');
        await _secureStorage.write(key: _tokenKey, value: token);
      }
    }
    
    print('🔑 getToken: Returning ${token != null ? "VALID TOKEN" : "NULL"}');
    return token;
  }

  Future<String?> getUserId() async {
    // Try secure storage first
    var userId = await _secureStorage.read(key: _userIdKey);
    
    // Fallback to SharedPreferences if secure storage fails
    if ((userId == null || userId.isEmpty) && _prefs != null) {
      userId = _prefs!.getString(_userIdKey);
      
      // Restore to secure storage if found in SharedPreferences
      if (userId != null && userId.isNotEmpty) {
        await _secureStorage.write(key: _userIdKey, value: userId);
      }
    }
    
    return userId;
  }

  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        print('🚪 Logging out from backend...');
        await _client.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logoutEndpoint}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5)); // Short timeout for logout
      }
    } catch (e) {
      print('⚠️ Backend logout failed (ignoring): $e');
    } finally {
      // Always clear local auth
      await clearAuth();
    }
  }

  Future<void> deleteAccount() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      await _client
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/users/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.defaultTimeout);
    } catch (e) {
      throw Exception('Delete account error: $e');
    } finally {
      await clearAuth();
    }
  }

  Future<void> clearAuth() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
    
    // Also clear from SharedPreferences backup
    if (_prefs != null) {
      await _prefs!.remove(_tokenKey);
      await _prefs!.remove(_userIdKey);
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
