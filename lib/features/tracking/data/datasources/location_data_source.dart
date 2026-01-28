import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../domain/entities/position.dart' as app;
import '../../../../core/services/kalman_filter.dart';

abstract class LocationDataSource {
  Stream<app.Position> getLocationStream({bool batterySaver = false});
  Future<app.Position> getCurrentPosition();
  Future<bool> isLocationServiceEnabled();
  Future<bool> checkPermissions();
  Future<double> calculateDistance(app.Position start, app.Position end);
}

class LocationDataSourceImpl implements LocationDataSource {
  final AdvancedGPSFilter _gpsFilter = AdvancedGPSFilter();

  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }
  
  @override
  Stream<app.Position> getLocationStream({bool batterySaver = false}) {
    _log('🌐 LocationDataSource: Creating location stream...');

    final isHighPrecision = !batterySaver;
    _gpsFilter.setMaxAccuracyMeters(isHighPrecision ? 15.0 : 35.0);
    _gpsFilter.reset();
    
    // ULTRA AGGRESSIVE: Get every update, no filtering
    final geo.LocationSettings locationSettings;
    final accuracy = batterySaver
        ? geo.LocationAccuracy.low
        : geo.LocationAccuracy.bestForNavigation;
    final distanceFilter = batterySaver ? 10 : 0;

    if (kIsWeb) {
      locationSettings = geo.LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = geo.AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration:
            batterySaver ? const Duration(seconds: 2) : const Duration(milliseconds: 500),
        forceLocationManager: false,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = geo.AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: geo.ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      locationSettings = geo.LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
    }
    
    _log('🌐 LocationDataSource: Location settings configured');
    _log('   - Accuracy: ${batterySaver ? "low" : "bestForNavigation"}');
    _log('   - Distance filter: ${batterySaver ? "10m" : "0m (all updates)"}');
    _log('   - Time limit: none (continuous)');
    
    return geo.Geolocator.getPositionStream(locationSettings: locationSettings)
        .map((position) {
          _log('🌐 RAW GPS: (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}) accuracy: ${position.accuracy.toStringAsFixed(1)}m');
          
          // Apply Kalman filter for smooth, accurate positions
          final filtered = _gpsFilter.process(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
          );
          
          _log('🌐 FILTERED: (${filtered['latitude']!.toStringAsFixed(6)}, ${filtered['longitude']!.toStringAsFixed(6)})');
          
          return app.Position(
            latitude: filtered['latitude']!,
            longitude: filtered['longitude']!,
            altitude: position.altitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
          );
        });
  }
  
  @override
  Future<app.Position> getCurrentPosition() async {
    final position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.bestForNavigation,
    );
    
    return app.Position(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }
  
  @override
  Future<bool> isLocationServiceEnabled() async {
    return await geo.Geolocator.isLocationServiceEnabled();
  }
  
  @override
  Future<bool> checkPermissions() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == geo.LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  @override
  Future<double> calculateDistance(app.Position start, app.Position end) async {
    return geo.Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }
}
