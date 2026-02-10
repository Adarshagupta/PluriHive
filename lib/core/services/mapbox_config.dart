import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxConfig {
  static const String _accessToken =
      'pk.eyJ1Ijoic3lsaWNhYWkiLCJhIjoiY21rd3UwcGtvMDFmdDNkcjBhdzc4ejEyaCJ9.yKkADo8N37hnMeJS44VBRQ';

  static Future<void> initialize() async {
    if (_accessToken.isEmpty) {
      debugPrint(
        'Mapbox access token missing.',
      );
      return;
    }
    MapboxOptions.setAccessToken(_accessToken);
  }

  static bool get isConfigured => _accessToken.isNotEmpty;
}
