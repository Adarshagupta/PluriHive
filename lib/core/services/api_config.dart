import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Backend URLs
  static const String localUrl = 'https://plurihub.sylicaai.com:443';
  static const String productionUrl = 'https://plurihub.sylicaai.com:443';

  static const String _backendPrefKey = 'selected_backend_url';

  // Current backend URL (mutable for runtime switching)
  static String baseUrl = localUrl; // Using local backend for testing

  // Initialize backend URL from saved preference
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getString(_backendPrefKey) ?? localUrl; // Default to local
    final sanitized = _sanitizeBaseUrl(saved);
    baseUrl = sanitized;
    if (sanitized != saved) {
      await prefs.setString(_backendPrefKey, sanitized);
    }
  }

  // Get current backend URL
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getString(_backendPrefKey) ?? localUrl; // Default to local
    final sanitized = _sanitizeBaseUrl(saved);
    if (sanitized != saved) {
      await prefs.setString(_backendPrefKey, sanitized);
    }
    return sanitized;
  }

  // Set backend URL and update runtime value
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized = _sanitizeBaseUrl(url);
    await prefs.setString(_backendPrefKey, sanitized);
    baseUrl = sanitized; // Update runtime value immediately
  }

  // Check if using production
  static bool get isProduction => baseUrl == productionUrl;

  /// WebSocket base URL derived from the current API baseUrl.
  /// Ensures ws:// for http:// and wss:// for https://.
  static String get wsUrl {
    final uri = Uri.parse(_sanitizeBaseUrl(baseUrl));
    final isSecure = uri.scheme == 'https';
    final scheme = isSecure ? 'wss' : 'ws';
    final hasValidPort = uri.hasPort && uri.port != 0;
    final port = hasValidPort ? uri.port : (isSecure ? 443 : 80);
    return uri.replace(scheme: scheme, port: port).toString();
  }

  static String _sanitizeBaseUrl(String url) {
    try {
      var trimmed = url.trim();
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        trimmed = 'https://$trimmed';
      }
      final uri = Uri.parse(trimmed);
      final isSecure = uri.scheme == 'https';
      final port =
          (uri.hasPort && uri.port != 0) ? uri.port : (isSecure ? 443 : 80);
      final path = (uri.path.isNotEmpty && uri.path != '/') ? uri.path : '';
      return '${uri.scheme}://${uri.host}:$port$path';
    } catch (_) {
      var trimmed = url.trim();
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        trimmed = 'https://$trimmed';
      }
      final portZeroPattern =
          RegExp(r'^(https?://[^/]+):0(?=/|$)', caseSensitive: false);
      final cleaned = trimmed.replaceFirst(portZeroPattern, r'$1');
      if (!cleaned.contains(RegExp(r':\d+'))) {
        return '${cleaned.replaceFirst(RegExp(r'/*$'), '')}:443';
      }
      return cleaned;
    }
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

  // Legal URLs (update to your hosted docs)
  static const String privacyPolicyUrl =
      'https://territoryfitness.com/privacy.html';
  static const String termsOfServiceUrl =
      'https://territoryfitness.com/terms.html';
  static const String accountDeletionUrl =
      'https://territoryfitness.com/delete-account.html';

  // Engagement endpoints
  static const String dropsSyncEndpoint = '/engagement/drops/sync';
  static const String poiMissionEndpoint = '/engagement/missions/poi';
  static const String poiMissionVisitEndpoint =
      '/engagement/missions/poi/visit';
  static const String rewardsEndpoint = '/engagement/rewards';
  static const String rewardsUnlockEndpoint = '/engagement/rewards/unlock';
  static const String rewardsSelectEndpoint = '/engagement/rewards/select';

  // Request timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);
}
