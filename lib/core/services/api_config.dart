import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Backend URLs
  static const String localUrl = 'http://10.1.80.51:3000';
  static const String productionUrl = 'https://plurihub.sylicaai.com';

  static const String _backendPrefKey = 'selected_backend_url';

  // Current backend URL (mutable for runtime switching)
  static String baseUrl = localUrl; // Using local backend for testing

  // Initialize backend URL from saved preference
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_backendPrefKey) ??
        localUrl; // Default to local for testing
  }

  // Get current backend URL
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendPrefKey) ??
        localUrl; // Default to local for testing
  }

  // Set backend URL and update runtime value
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendPrefKey, url);
    baseUrl = url; // Update runtime value immediately
  }

  // Check if using production
  static bool get isProduction => baseUrl == productionUrl;

  /// WebSocket base URL derived from the current API baseUrl.
  /// Ensures ws:// for http:// and wss:// for https://.
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: scheme).toString();
  }

  // Auth endpoints
  static const String signUpEndpoint = '/auth/signup';
  static const String signInEndpoint = '/auth/signin';
  static const String getMeEndpoint = '/auth/me';
  static const String logoutEndpoint = '/auth/logout';

  // User endpoints
  static const String userProfileEndpoint = '/users/profile';

  // Territory endpoints
  static const String captureTerritoriesEndpoint = '/territories/capture';
  static const String userTerritoriesEndpoint = '/territories/user';
  static const String nearbyTerritoriesEndpoint = '/territories/nearby';

  // Activity endpoints
  static const String activitiesEndpoint = '/activities';

  // Routes endpoints
  static const String routesEndpoint = '/routes';

  // Leaderboard endpoints
  static const String leaderboardEndpoint = '/leaderboard/global';

  // Request timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);
}
