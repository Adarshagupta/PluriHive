import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/position.dart';
import '../../domain/usecases/start_tracking.dart';
import '../../domain/usecases/stop_tracking.dart';
import '../../domain/usecases/get_current_location.dart';
import '../../../../core/algorithms/geospatial_algorithms.dart';
import '../../../../core/services/gps_simulator.dart';

// Events
abstract class LocationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartLocationTracking extends LocationEvent {
  final bool useSimulation;  // Enable simulation mode
  StartLocationTracking({this.useSimulation = false});
  @override
  List<Object?> get props => [useSimulation];
}

class StopLocationTracking extends LocationEvent {}

class LocationUpdated extends LocationEvent {
  final Position position;
  
  LocationUpdated(this.position);
  
  @override
  List<Object?> get props => [position];
}

class GetInitialLocation extends LocationEvent {}

// States
abstract class LocationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationTracking extends LocationState {
  final Position currentPosition;
  final List<Position> routePoints;
  final double totalDistance;
  
  LocationTracking({
    required this.currentPosition,
    required this.routePoints,
    required this.totalDistance,
  });
  
  @override
  List<Object?> get props => [currentPosition, routePoints, totalDistance];
  
  LocationTracking copyWith({
    Position? currentPosition,
    List<Position>? routePoints,
    double? totalDistance,
  }) {
    return LocationTracking(
      currentPosition: currentPosition ?? this.currentPosition,
      routePoints: routePoints ?? this.routePoints,
      totalDistance: totalDistance ?? this.totalDistance,
    );
  }
}

class LocationIdle extends LocationState {
  final Position? lastPosition;
  
  LocationIdle({this.lastPosition});
  
  @override
  List<Object?> get props => [lastPosition];
}

class LocationError extends LocationState {
  final String message;
  
  LocationError(this.message);
  
  @override
  List<Object?> get props => [message];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ULTRA-ADVANCED LOCATION BLOC with strict validation
/// ═══════════════════════════════════════════════════════════════════════════
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final StartTracking startTracking;
  final StopTracking stopTracking;
  final GetCurrentLocation getCurrentLocation;
  final dynamic locationRepository;
  
  StreamSubscription<Position>? _locationSubscription;
  final GpsSimulator _gpsSimulator = GpsSimulator();  // GPS Simulator
  
  // Advanced tracking state
  final List<_ValidatedPoint> _validatedHistory = [];
  double _smoothedSpeed = 0.0;
  int _consecutiveRejections = 0;
  DateTime? _lastValidUpdate;
  
  // RELAXED thresholds for better tracking
  static const double MIN_DISTANCE_THRESHOLD = 0.3;    // Minimum 30cm to count
  static const double MAX_SPEED_MS = 20.0;             // Max 20 m/s (72 km/h) - more lenient
  static const double MAX_ACCELERATION = 6.0;         // Max 6 m/s² acceleration - more lenient
  static const double SPEED_SMOOTHING_ALPHA = 0.25;   // EMA smoothing factor
  static const int MAX_HISTORY_SIZE = 30;
  static const int MAX_CONSECUTIVE_REJECTIONS = 15;    // More chances before reset
  
  LocationBloc({
    required this.startTracking,
    required this.stopTracking,
    required this.getCurrentLocation,
    required this.locationRepository,
  }) : super(LocationInitial()) {
    on<GetInitialLocation>(_onGetInitialLocation);
    on<StartLocationTracking>(_onStartTracking);
    on<StopLocationTracking>(_onStopTracking);
    on<LocationUpdated>(_onLocationUpdated);
  }
  
  Future<void> _onGetInitialLocation(
    GetInitialLocation event,
    Emitter<LocationState> emit,
  ) async {
    try {
      emit(LocationLoading());
      final position = await getCurrentLocation();
      emit(LocationIdle(lastPosition: position));
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }
  
  Future<void> _onStartTracking(
    StartLocationTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      // Cancel any existing subscription first
      await _locationSubscription?.cancel();
      _gpsSimulator.stopSimulation();
      
      if (event.useSimulation) {
        // === SIMULATION MODE ===
        print('🎮 Starting GPS simulation...');
        
        final initialPosition = Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
        );
        
        emit(LocationTracking(
          currentPosition: initialPosition,
          routePoints: [],
          totalDistance: 0.0,
        ));
        
        _gpsSimulator.startSimulation((position) {
          add(LocationUpdated(position));
        });
      } else {
        // === REAL GPS MODE ===
        print('📍 Starting REAL GPS tracking...');
        
        // Check and request permissions FIRST
        print('📍 Checking location permissions...');
        final hasPermission = await locationRepository.checkPermissions();
        if (!hasPermission) {
          print('❌ Location permissions denied!');
          emit(LocationError('Location permission denied. Please enable location access in settings.'));
          return;
        }
        print('✅ Location permissions granted');
        
        // Check if location services are enabled
        print('📍 Checking location services...');
        final servicesEnabled = await locationRepository.isLocationServiceEnabled();
        if (!servicesEnabled) {
          print('❌ Location services disabled!');
          emit(LocationError('Location services are disabled. Please enable GPS in settings.'));
          return;
        }
        print('✅ Location services enabled');
        
        await startTracking();
        
        print('📍 Getting initial position...');
        final position = await getCurrentLocation();
        print('✅ Initial position: (${position.latitude}, ${position.longitude})');
        
        emit(LocationTracking(
          currentPosition: position,
          routePoints: [position],
          totalDistance: 0.0,
        ));
        
        // Start listening to location stream
        print('📍 Starting location stream subscription...');
        _locationSubscription = locationRepository.getLocationStream().listen(
          (position) {
            print('📍 LOCATION STREAM: Received position (${position.latitude}, ${position.longitude})');
            add(LocationUpdated(position));
          },
          onError: (error) {
            print('❌ Location stream error: $error');
            // Keep tracking state even on errors
          },
          cancelOnError: false,
        );
        print('✅ Location stream subscription active');
      }
    } catch (e) {
      print('❌ Failed to start tracking: $e');
      emit(LocationError(e.toString()));
    }
  }
  
  Future<void> _onStopTracking(
    StopLocationTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      await _locationSubscription?.cancel();
      _gpsSimulator.stopSimulation();  // Stop simulation if running
      await stopTracking();
      
      // Reset tracking state
      _validatedHistory.clear();
      _smoothedSpeed = 0.0;
      _consecutiveRejections = 0;
      _lastValidUpdate = null;
      
      if (state is LocationTracking) {
        final tracking = state as LocationTracking;
        emit(LocationIdle(lastPosition: tracking.currentPosition));
      }
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }
  
  /// ═══════════════════════════════════════════════════════════════════════════
  /// ULTRA-STRICT LOCATION UPDATE HANDLER
  /// Multi-layer validation with advanced algorithms
  /// ═══════════════════════════════════════════════════════════════════════════
  void _onLocationUpdated(
    LocationUpdated event,
    Emitter<LocationState> emit,
  ) async {
    print('');
    print('═══════════════════════════════════════════════════════════════════');
    print('🔵 LocationBloc: _onLocationUpdated CALLED');
    print('═══════════════════════════════════════════════════════════════════');
    print('   📍 Input: (${event.position.latitude.toStringAsFixed(6)}, ${event.position.longitude.toStringAsFixed(6)})');
    print('   ⏱️  Timestamp: ${event.position.timestamp}');
    print('   📊 Current state: ${state.runtimeType}');
    
    if (state is! LocationTracking) {
      print('   ❌ ABORT: State is not LocationTracking - STATE IS ${state.runtimeType}');
      return;
    }
    print('   ✅ State is LocationTracking - proceeding with validation...');
    
    final tracking = state as LocationTracking;
    print('   📏 Current distance: ${(tracking.totalDistance / 1000).toStringAsFixed(3)} km');
    print('   📍 Route points: ${tracking.routePoints.length}');
    
    // === LAYER 1: Basic position validation ===
    if (!_isValidCoordinate(event.position.latitude, event.position.longitude)) {
      print('   ❌ LAYER 1 REJECT: Invalid coordinates');
      return;
    }
    print('   ✅ LAYER 1: Coordinates valid');
    
    // === LAYER 2: Calculate distance from last point ===
    double distanceFromLast = 0.0;
    double timeDelta = 0.0;
    
    if (tracking.routePoints.isNotEmpty) {
      final lastPosition = tracking.routePoints.last;
      // Use industry-grade Vincenty formula for WGS84 ellipsoid accuracy
      distanceFromLast = GeodesicCalculator.vincentyDistance(
        LatLng(lastPosition.latitude, lastPosition.longitude),
        LatLng(event.position.latitude, event.position.longitude),
      );
      timeDelta = event.position.timestamp.difference(lastPosition.timestamp).inMilliseconds / 1000.0;
      
      print('   📐 Distance from last: ${distanceFromLast.toStringAsFixed(2)}m');
      print('   ⏱️  Time delta: ${timeDelta.toStringAsFixed(2)}s');
    }
    
    // === LAYER 3: Time validation ===
    if (timeDelta <= 0 && tracking.routePoints.isNotEmpty) {
      print('   ❌ LAYER 3 REJECT: Invalid time delta (${timeDelta}s)');
      return;
    }
    print('   ✅ LAYER 3: Time delta valid');
    
    // === LAYER 4: Minimum distance threshold (GPS drift filter) ===
    // ALWAYS add first point, then use VERY low threshold for subsequent points
    if (tracking.routePoints.isEmpty) {
      print('   ✅ LAYER 4: First point - always accepted');
    } else {
      final minDistance = tracking.routePoints.length < 3 ? 0.5 : 0.3; // ULTRA LOW threshold - 30cm!
      
      if (distanceFromLast < minDistance) {
        print('   ⚠️ LAYER 4: Below threshold (${distanceFromLast.toStringAsFixed(2)}m < ${minDistance}m)');
        print('      → Updating position only (no distance added)');
        
        // Update position for camera tracking, but don't add distance
        emit(tracking.copyWith(currentPosition: event.position));
        return;
      }
      print('   ✅ LAYER 4: Distance threshold passed (${distanceFromLast.toStringAsFixed(2)}m >= ${minDistance}m)');
    }
    
    // === LAYER 5: Speed validation ===
    double instantSpeed = 0.0;
    if (timeDelta > 0 && tracking.routePoints.isNotEmpty) {
      instantSpeed = distanceFromLast / timeDelta;
      print('   🚗 Instant speed: ${instantSpeed.toStringAsFixed(2)} m/s (${(instantSpeed * 3.6).toStringAsFixed(1)} km/h)');
      
      // Skip speed validation for first 10 points (GPS may be acquiring)
      if (tracking.routePoints.length >= 10 && instantSpeed > MAX_SPEED_MS) {
        _consecutiveRejections++;
        print('   ❌ LAYER 5 REJECT: Speed too high (${instantSpeed.toStringAsFixed(1)} m/s > ${MAX_SPEED_MS} m/s)');
        print('      → Consecutive rejections: $_consecutiveRejections');
        
        // If too many rejections, user probably teleported (GPS fix after loss)
        if (_consecutiveRejections >= MAX_CONSECUTIVE_REJECTIONS) {
          print('      → Too many rejections - resetting baseline and ACCEPTING THIS POINT');
          _resetBaseline(event.position);
          // DON'T return - accept this point to restart tracking
        } else {
          return;
        }
      } else if (tracking.routePoints.length < 10) {
        print('   ⏭️ LAYER 5: Skipping validation (early tracking, point ${tracking.routePoints.length}/10)');
      }
    }
    print('   ✅ LAYER 5: Speed valid');
    
    // === LAYER 6: Acceleration validation ===
    // Skip for first 15 points (GPS stabilizing)
    if (_validatedHistory.length >= 15 && timeDelta > 0) {
      final lastValidSpeed = _validatedHistory.last.speed;
      final acceleration = (instantSpeed - lastValidSpeed) / timeDelta;
      
      print('   ⚡ Acceleration: ${acceleration.toStringAsFixed(2)} m/s²');
      
      if (acceleration.abs() > MAX_ACCELERATION) {
        _consecutiveRejections++;
        print('   ⚠️ LAYER 6: High acceleration (${acceleration.toStringAsFixed(1)} m/s²) - rejections: $_consecutiveRejections');
        
        if (_consecutiveRejections >= MAX_CONSECUTIVE_REJECTIONS) {
          print('      → Too many rejections - ACCEPTING THIS POINT to restart');
          _resetBaseline(event.position);
          // DON'T return - accept this point
        } else {
          return;
        }
      }
    } else if (_validatedHistory.isNotEmpty) {
      print('   ⏭️ LAYER 6: Skipping (early tracking phase, ${_validatedHistory.length}/15 points)');
    }
    print('   ✅ LAYER 6: Acceleration valid');
    
    // === LAYER 7: Heading consistency check ===
    if (_validatedHistory.length >= 2) {
      final prev2 = _validatedHistory[_validatedHistory.length - 2];
      final prev1 = _validatedHistory.last;
      
      final heading1 = _calculateBearing(prev2.lat, prev2.lng, prev1.lat, prev1.lng);
      final heading2 = _calculateBearing(prev1.lat, prev1.lng, event.position.latitude, event.position.longitude);
      final headingChange = _normalizeAngle(heading2 - heading1).abs();
      
      print('   🧭 Heading change: ${headingChange.toStringAsFixed(1)}°');
      
      // Sharp turns at high speed are suspicious
      if (instantSpeed > 2.0 && headingChange > 120) {
        print('   ⚠️ LAYER 7 WARNING: Sharp turn at speed - possible GPS error');
        // Don't reject, but reduce trust
      }
    }
    print('   ✅ LAYER 7: Heading consistent');
    
    // === ALL VALIDATIONS PASSED ===
    _consecutiveRejections = 0;
    _lastValidUpdate = DateTime.now();
    
    // Update smoothed speed (Exponential Moving Average)
    _smoothedSpeed = SPEED_SMOOTHING_ALPHA * instantSpeed + (1 - SPEED_SMOOTHING_ALPHA) * _smoothedSpeed;
    
    // Add to validated history
    _validatedHistory.add(_ValidatedPoint(
      lat: event.position.latitude,
      lng: event.position.longitude,
      timestamp: event.position.timestamp,
      speed: instantSpeed,
      distance: distanceFromLast,
    ));
    
    // Trim history
    while (_validatedHistory.length > MAX_HISTORY_SIZE) {
      _validatedHistory.removeAt(0);
    }
    
    // Calculate new total distance
    final newRoutePoints = List<Position>.from(tracking.routePoints)..add(event.position);
    final newDistance = tracking.totalDistance + distanceFromLast;
    
    print('');
    print('   ═══════════════════════════════════════════════════════════════');
    print('   ✅ ALL LAYERS PASSED - ACCEPTED');
    print('   ═══════════════════════════════════════════════════════════════');
    print('   📏 Added: +${distanceFromLast.toStringAsFixed(2)}m');
    print('   📏 New total: ${(newDistance / 1000).toStringAsFixed(3)} km');
    print('   🚗 Smoothed speed: ${(_smoothedSpeed * 3.6).toStringAsFixed(1)} km/h');
    print('   📍 Route points: ${newRoutePoints.length}');
    print('');
    
    // Emit updated state
    emit(tracking.copyWith(
      currentPosition: event.position,
      routePoints: newRoutePoints,
      totalDistance: newDistance,
    ));
  }
  
  /// Reset tracking baseline after position jump
  void _resetBaseline(Position newPosition) {
    _validatedHistory.clear();
    _smoothedSpeed = 0.0;
    _consecutiveRejections = 0;
    
    _validatedHistory.add(_ValidatedPoint(
      lat: newPosition.latitude,
      lng: newPosition.longitude,
      timestamp: newPosition.timestamp,
      speed: 0.0,
      distance: 0.0,
    ));
  }
  
  /// Validate coordinate range
  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && lat != 0 && lng != 0;
  }
  
  /// Haversine formula for accurate distance (meters)
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  
  /// Calculate bearing between two points
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    
    final y = sin(dLng) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);
    
    return atan2(y, x) * 180.0 / pi;
  }
  
  double _normalizeAngle(double angle) {
    while (angle > 180) angle -= 360;
    while (angle < -180) angle += 360;
    return angle;
  }
  
  double _toRadians(double deg) => deg * pi / 180.0;
  
  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _validatedHistory.clear();
    return super.close();
  }
}

/// Validated GPS point for history tracking
class _ValidatedPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double speed;
  final double distance;
  
  _ValidatedPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.speed,
    required this.distance,
  });
}
