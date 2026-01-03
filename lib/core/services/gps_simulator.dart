import 'dart:async';
import 'dart:math';
import '../../features/tracking/domain/entities/position.dart';

/// GPS Simulator for testing without moving
class GpsSimulator {
  Timer? _timer;
  int _pointIndex = 0;
  final List<Position> _route = [];
  final Random _random = Random();
  
  // Simulation parameters (coordinates generated randomly each run)
  late double _startLat;
  late double _startLng;
  static const double _speedMps = 1.5;  // 1.5 m/s = 5.4 km/h (walking speed)
  static const int _updateIntervalMs = 1000;  // Update every second
  
  /// Start simulating a rectangular loop
  void startSimulation(Function(Position) onPositionUpdate) {
    // Generate random starting location (worldwide)
    _generateRandomLocation();
    
    print('🎮 GPS SIMULATOR STARTED');
    print('📍 Random location: (${_startLat.toStringAsFixed(4)}°, ${_startLng.toStringAsFixed(4)}°)');
    print('🗺️  Simulating walking route...');
    
    _generateRoute();
    _pointIndex = 0;
    
    _timer = Timer.periodic(Duration(milliseconds: _updateIntervalMs), (timer) {
      if (_pointIndex < _route.length) {
        final position = _route[_pointIndex];
        print('🎮 Sim point ${_pointIndex + 1}/${_route.length}: (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})');
        onPositionUpdate(position);
        _pointIndex++;
      } else {
        // Loop back to start
        print('🔄 Route complete, looping...');
        _pointIndex = 0;
      }
    });
  }
  
  /// Generate a rectangular walking route (about 100m x 100m)
  void _generateRoute() {
    _route.clear();
    
    // Roughly 100m in degrees at this latitude
    const double metersPerDegreeLat = 111000.0;
    final metersPerDegreeLng = metersPerDegreeLat * cos(_startLat * pi / 180);
    
    final double latStep = 100 / metersPerDegreeLat;  // 100m north
    final double lngStep = 100 / metersPerDegreeLng;  // 100m east
    
    // Number of points per side (to simulate smooth movement)
    const int pointsPerSide = 50;
    
    final now = DateTime.now();
    
    // Side 1: Walk north
    for (int i = 0; i <= pointsPerSide; i++) {
      final lat = _startLat + (latStep * i / pointsPerSide);
      final lng = _startLng;
      _route.add(Position(
        latitude: lat,
        longitude: lng,
        timestamp: now.add(Duration(seconds: _route.length)),
      ));
    }
    
    // Side 2: Walk east
    for (int i = 1; i <= pointsPerSide; i++) {
      final lat = _startLat + latStep;
      final lng = _startLng + (lngStep * i / pointsPerSide);
      _route.add(Position(
        latitude: lat,
        longitude: lng,
        timestamp: now.add(Duration(seconds: _route.length)),
      ));
    }
    
    // Side 3: Walk south
    for (int i = 1; i <= pointsPerSide; i++) {
      final lat = _startLat + latStep - (latStep * i / pointsPerSide);
      final lng = _startLng + lngStep;
      _route.add(Position(
        latitude: lat,
        longitude: lng,
        timestamp: now.add(Duration(seconds: _route.length)),
      ));
    }
    
    // Side 4: Walk west (back to start)
    for (int i = 1; i <= pointsPerSide; i++) {
      final lat = _startLat;
      final lng = _startLng + lngStep - (lngStep * i / pointsPerSide);
      _route.add(Position(
        latitude: lat,
        longitude: lng,
        timestamp: now.add(Duration(seconds: _route.length)),
      ));
    }
    
    print('🎮 Generated ${_route.length} simulation points');
    print('📐 Route: 100m x 100m rectangle');
    print('🚶 Speed: ${_speedMps} m/s (${(_speedMps * 3.6).toStringAsFixed(1)} km/h)');
  }
  
  /// Generate random GPS coordinates from major cities
  void _generateRandomLocation() {
    // List of major city coordinates
    final cities = [
      {'name': 'New York', 'lat': 40.7128, 'lng': -74.0060},
      {'name': 'London', 'lat': 51.5074, 'lng': -0.1278},
      {'name': 'Tokyo', 'lat': 35.6762, 'lng': 139.6503},
      {'name': 'Paris', 'lat': 48.8566, 'lng': 2.3522},
      {'name': 'Sydney', 'lat': -33.8688, 'lng': 151.2093},
      {'name': 'Dubai', 'lat': 25.2048, 'lng': 55.2708},
      {'name': 'Singapore', 'lat': 1.3521, 'lng': 103.8198},
      {'name': 'San Francisco', 'lat': 37.7749, 'lng': -122.4194},
      {'name': 'Berlin', 'lat': 52.5200, 'lng': 13.4050},
      {'name': 'Mumbai', 'lat': 19.0760, 'lng': 72.8777},
      {'name': 'Beijing', 'lat': 39.9042, 'lng': 116.4074},
      {'name': 'Los Angeles', 'lat': 34.0522, 'lng': -118.2437},
      {'name': 'Toronto', 'lat': 43.6532, 'lng': -79.3832},
      {'name': 'Barcelona', 'lat': 41.3851, 'lng': 2.1734},
      {'name': 'Seoul', 'lat': 37.5665, 'lng': 126.9780},
    ];
    
    // Pick a random city
    final city = cities[_random.nextInt(cities.length)];
    _startLat = city['lat'] as double;
    _startLng = city['lng'] as double;
    
    print('🌍 Random city: ${city['name']}');
  }
  
  /// Stop simulation
  void stopSimulation() {
    _timer?.cancel();
    _timer = null;
    print('🎮 GPS SIMULATOR STOPPED');
  }
  
  /// Check if simulation is running
  bool get isRunning => _timer != null && _timer!.isActive;
}
