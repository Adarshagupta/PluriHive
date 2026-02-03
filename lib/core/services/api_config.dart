import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Backend URLs
  static const String localUrl = 'http://10.1.80.37:3000';
  static const String productionUrl = 'https://plurihub.sylicaai.com:443';

  static const String _backendPrefKey = 'selected_backend_url';

  // Current backend URL (mutable for runtime switching)
  static String baseUrl = productionUrl; // Using production backend

  // Initialize backend URL from saved preference
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getString(_backendPrefKey) ?? productionUrl; // Default to production
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
        prefs.getString(_backendPrefKey) ?? productionUrl; // Default to production
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
    final normalized = _sanitizeBaseUrl(baseUrl);
    Uri uri;
    try {
      uri = Uri.parse(normalized);
    } catch (_) {
      uri = Uri.parse('https://plurihub.sylicaai.com');
    }
    final isSecure = uri.scheme == 'https';
    final scheme = isSecure ? 'wss' : 'ws';
    final port = (uri.hasPort && uri.port != 0) ? uri.port : (isSecure ? 443 : 80);
    var host = uri.host;
    if (host.isEmpty) {
      final trimmed =
          normalized.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
      host = trimmed.split('/').first.split(':').first;
    }
    return '$scheme://$host:$port';
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
  static const String leaderboardCityEndpoint = '/leaderboard/city';
  static const String leaderboardSeasonEndpoint = '/leaderboard/season';
  static const String leaderboardFactionEndpoint = '/leaderboard/faction';

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
  static const String dailyMissionsEndpoint = '/engagement/missions/daily';
  static const String weeklyMissionsEndpoint = '/engagement/missions/weekly';

  // Request timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);
}
