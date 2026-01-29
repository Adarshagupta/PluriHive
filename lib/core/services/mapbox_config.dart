import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxConfig {
  static const String _accessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static Future<void> initialize() async {
    if (_accessToken.isEmpty) {
      debugPrint(
        'Mapbox access token missing. Provide via --dart-define=MAPBOX_ACCESS_TOKEN=...',
      );
      return;
    }
    MapboxOptions.setAccessToken(_accessToken);
  }

  static bool get isConfigured => _accessToken.isNotEmpty;
}
