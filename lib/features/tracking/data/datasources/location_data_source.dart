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
    
    // ULTRA AGGRESSIVE: Get every update, no filtering
    final locationSettings = geo.LocationSettings(
      accuracy: batterySaver
          ? geo.LocationAccuracy.low
          : geo.LocationAccuracy.bestForNavigation,
      distanceFilter: batterySaver ? 10 : 0,
    );
    
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
            timestamp: position.timestamp,
          );
        });
  }
  
  @override
  Future<app.Position> getCurrentPosition() async {
    final position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );
    
    return app.Position(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
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
