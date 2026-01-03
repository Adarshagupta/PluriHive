import 'package:geolocator/geolocator.dart' as geo;
import '../../domain/entities/position.dart' as app;
import '../../../../core/services/kalman_filter.dart';

abstract class LocationDataSource {
  Stream<app.Position> getLocationStream();
  Future<app.Position> getCurrentPosition();
  Future<bool> isLocationServiceEnabled();
  Future<bool> checkPermissions();
  Future<double> calculateDistance(app.Position start, app.Position end);
}

class LocationDataSourceImpl implements LocationDataSource {
  final AdvancedGPSFilter _gpsFilter = AdvancedGPSFilter();
  
  @override
  Stream<app.Position> getLocationStream() {
    print('🌐 LocationDataSource: Creating location stream...');
    
    // ULTRA AGGRESSIVE: Get every update, no filtering
    const locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.bestForNavigation, // Highest accuracy
      distanceFilter: 0, // NO DISTANCE FILTER - get all updates!
      // NO timeLimit - let it run continuously
    );
    
    print('🌐 LocationDataSource: Location settings configured');
    print('   - Accuracy: bestForNavigation');
    print('   - Distance filter: 0m (all updates)');
    print('   - Time limit: none (continuous)');
    
    return geo.Geolocator.getPositionStream(locationSettings: locationSettings)
        .map((position) {
          print('🌐 RAW GPS: (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}) accuracy: ${position.accuracy.toStringAsFixed(1)}m');
          
          // Apply Kalman filter for smooth, accurate positions
          final filtered = _gpsFilter.process(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
          );
          
          print('🌐 FILTERED: (${filtered['latitude']!.toStringAsFixed(6)}, ${filtered['longitude']!.toStringAsFixed(6)})');
          
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
