import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../../../core/services/background_tracking_service.dart';
import '../../../../core/services/motion_detection_service.dart';
import '../../../../core/utils/picture_in_picture.dart';
import '../../../../core/algorithms/geospatial_algorithms.dart';
import '../../../tracking/domain/entities/activity.dart';
import '../../../tracking/data/datasources/activity_local_data_source.dart';
import '../bloc/location_bloc.dart';
import '../../../territory/presentation/bloc/territory_bloc.dart';
import '../../../game/presentation/bloc/game_bloc.dart';
import '../../../territory/data/helpers/territory_grid_helper.dart';
import '../../../territory/domain/entities/territory.dart' as app;
import 'workout_summary_screen.dart';

class MapScreen extends StatefulWidget {
  final VoidCallback? onNavigateHome;
  
  const MapScreen({super.key, this.onNavigateHome});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum TrackingState { stopped, started, paused }

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final Set<Polygon> _polygons = {};
  final Set<Polyline> _polylines = {};
  final Set<Marker> _territoryMarkers = {};
  late AnimationController _animController;
  late AnimationController _buttonAnimController;
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _is3DMode = false;
  double _currentSpeed = 0.0; // km/h
  DateTime? _lastSpeedUpdate;
  final Set<String> _capturedHexIds = {};
  double _lastDistanceUpdate = 0.0;
  double _lastNotificationDistance = 0.0; // Track distance for notification updates
  int _lastTerritoryCount = 0;
  DateTime? _trackingStartTime;
  Circle? _startPointCircle; // Visual marker for start point
  double _distanceToStart = double.infinity; // Distance to starting point
  DateTime? _lastNotificationUpdate; // Throttle notification updates
  TrackingState _trackingState = TrackingState.stopped;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  
  // Loop closure feedback
  bool _hasGivenCloseLoopFeedback = false;
  double _estimatedAreaSqMeters = 0.0;
  int _lastLoadedTerritoryCount = 0; // Track last loaded count to prevent spam
  int _currentSessionTerritories = 0; // Track territories captured in current session
  
  // Advanced motion detection
  final MotionDetectionService _motionDetection = MotionDetectionService();
  int _advancedSteps = 0;
  MotionType _motionType = MotionType.stationary;
  MotionType _displayedMotionType = MotionType.stationary; // Throttled display
  double _motionConfidence = 0.0;
  DateTime? _lastMotionTypeUpdate;
  
  // Step counting (fallback)
  int _steps = 0;
  int _sessionStartSteps = 0;
  StreamSubscription<StepCount>? _stepCountStream;
  String _stepStatus = 'Unknown';
  
  // Countdown
  bool _showCountdown = false;
  int _countdown = 3;
  bool _showEndAnimation = false;
  int _endCountdown = 3;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Long press to end
  bool _isHoldingEnd = false;
  
  // Simulation mode toggle
  bool _useSimulation = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  static const Duration _holdDuration = Duration(seconds: 5);
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _animController.forward();
    
    _buttonAnimController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize background tracking service
    BackgroundTrackingService.initForegroundTask();
    
    // Initialize ADVANCED motion detection
    _initAdvancedMotionDetection();
    
    // Initialize step counter (fallback)
    _initStepCounter();
    
    // Load previously captured areas from history
    _loadSavedCapturedAreas();
    
    // Get initial location
    context.read<LocationBloc>().add(GetInitialLocation());
    context.read<TerritoryBloc>().add(LoadTerritories());
  }
  
  // Load all previously captured areas from activity history
  Future<void> _loadSavedCapturedAreas() async {
    try {
      final dataSource = ActivityLocalDataSourceImpl();
      final activities = await dataSource.getAllActivities();
      
      setState(() {
        _polygons.clear();
        _territoryMarkers.clear();
        
        // Load each activity's captured area
        for (int i = 0; i < activities.length; i++) {
          final activity = activities[i];
          if (activity.route.isNotEmpty && activity.route.length >= 3) {
            // Convert route points to LatLng
            final routePoints = activity.route
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
            
            // Add filled area polygon
            _polygons.add(
              Polygon(
                polygonId: PolygonId('saved_area_${activity.id}'),
                points: routePoints,
                fillColor: Color(0xFF4CAF50).withOpacity(0.25),
                strokeColor: Color(0xFF4CAF50),
                strokeWidth: 2,
              ),
            );
            
            // Add marker at center
            if (routePoints.isNotEmpty) {
              double sumLat = 0, sumLng = 0;
              for (final point in routePoints) {
                sumLat += point.latitude;
                sumLng += point.longitude;
              }
              
              _territoryMarkers.add(
                Marker(
                  markerId: MarkerId('label_${activity.id}'),
                  position: LatLng(sumLat / routePoints.length, sumLng / routePoints.length),
                  infoWindow: InfoWindow(
                    title: 'Runner',
                    snippet: '${(activity.distanceMeters / 1000).toStringAsFixed(2)} km',
                  ),
                ),
              );
            }
          }
        }
      });
      
      print('✅ Loaded ${activities.length} saved captured areas');
    } catch (e) {
      print('❌ Error loading saved areas: $e');
    }
  }

  void _initAdvancedMotionDetection() {
    // Setup advanced motion detection callbacks
    _motionDetection.onStepDetected = (steps) {
      if (mounted) {
        setState(() {
          _advancedSteps = steps;
        });
        print('🦶 Step detected! Total: $steps');
      }
    };
    
    _motionDetection.onMotionTypeChanged = (type) {
      if (mounted) {
        final now = DateTime.now();
        // Only update display every 3 seconds to prevent flickering
        if (_lastMotionTypeUpdate == null || 
            now.difference(_lastMotionTypeUpdate!).inSeconds >= 3) {
          setState(() {
            _motionType = type;
            _displayedMotionType = type;
            _lastMotionTypeUpdate = now;
          });
          print('🏃 Motion type changed: $type');
        } else {
          // Update internal state but not display
          _motionType = type;
        }
      }
    };
    
    _motionDetection.onMotionConfidence = (confidence) {
      if (mounted) {
        setState(() {
          _motionConfidence = confidence;
        });
      }
    };
  }
  
  void _initStepCounter() {
    try {
      _stepCountStream = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );
      _stepStatus = 'Listening';
    } catch (e) {
      print('Error initializing step counter: $e');
      _stepStatus = 'Not Available';
    }
  }
  
  void _onStepCount(StepCount event) {
    if (mounted) {
      setState(() {
        _steps = event.steps;
      });
    }
  }
  
  void _onStepCountError(error) {
    print('Step Count Error: $error');
    setState(() {
      _stepStatus = 'Error: $error';
    });
  }

  @override
  void dispose() {
    _stepCountStream?.cancel();
    _motionDetection.stopDetection(); // Stop advanced motion detection
    _animController.dispose();
    _buttonAnimController.dispose();
    _mapController?.dispose();
    _audioPlayer.dispose();
    _holdTimer?.cancel();
    BackgroundTrackingService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PipAwareWidget(
      child: _buildFullScreen(context),
      pipChild: _buildPipMode(context),
    );
  }
  
  Widget _buildFullScreen(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<LocationBloc, LocationState>(
            listener: (context, state) {
              if (state is LocationTracking) {
                // Update all UI elements in real-time
                _updateRoutePolyline(state);
                _calculateSpeed(state);
                _updateStartPointMarker(state);
                _updateStatsRealTime(state);
                
                // Camera follows user smoothly when tracking is active
                if (_mapController != null && _trackingState == TrackingState.started) {
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          state.currentPosition.latitude,
                          state.currentPosition.longitude,
                        ),
                        zoom: 18,
                        tilt: _is3DMode ? 45 : 0,
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
        child: Stack(
          children: [
            BlocBuilder<LocationBloc, LocationState>(
              builder: (context, locationState) {
                CameraPosition initialPosition = const CameraPosition(
                  target: LatLng(37.7749, -122.4194), // Default: San Francisco
                  zoom: 15,
                );
                
                if (locationState is LocationIdle && locationState.lastPosition != null) {
                  initialPosition = CameraPosition(
                    target: LatLng(
                      locationState.lastPosition!.latitude,
                      locationState.lastPosition!.longitude,
                    ),
                    zoom: 15,
                  );
                } else if (locationState is LocationTracking) {
                  initialPosition = CameraPosition(
                    target: LatLng(
                      locationState.currentPosition.latitude,
                      locationState.currentPosition.longitude,
                    ),
                    zoom: 18,
                    tilt: _is3DMode ? 45 : 0,
                  );
                  // Camera animation is handled by BlocListener - don't duplicate here
                }
                
                return BlocBuilder<TerritoryBloc, TerritoryState>(
                  builder: (context, territoryState) {
                    // DISABLED: Don't show hexagonal territory grid
                    // Only show exact walking shape via _showCapturedArea()
                    // if (territoryState is TerritoryLoaded && 
                    //     territoryState.territories.length != _lastLoadedTerritoryCount) {
                    //   WidgetsBinding.instance.addPostFrameCallback((_) {
                    //     _updateTerritoryPolygons(territoryState.territories);
                    //     _lastLoadedTerritoryCount = territoryState.territories.length;
                    //   });
                    // }
                    
                    return GoogleMap(
                      initialCameraPosition: initialPosition,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      mapType: _currentMapType,
                      zoomControlsEnabled: false,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      polygons: _polygons,
                      polylines: _polylines,
                      markers: _territoryMarkers,
                      circles: _startPointCircle != null ? {_startPointCircle!} : {}, // Show start point marker
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (locationState is LocationIdle && locationState.lastPosition != null) {
                          controller.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(
                                locationState.lastPosition!.latitude,
                                locationState.lastPosition!.longitude,
                              ),
                            ),
                          );
                        }
                      },
                      onCameraMove: (position) {
                        // Could generate visible territories here
                      },
                    );
                  },
                );
              },
            ),
            
            // Minimal top stats bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: FadeTransition(
                  opacity: _animController,
                  child: _buildMinimalStatsBar(),
                ),
              ),
            ),

            // Simulation toggle (top left)
            Positioned(
              left: 16,
              top: 120,
              child: SafeArea(
                child: _buildSimulationToggle(),
              ),
            ),
            
            // Map control buttons (right side)
            Positioned(
              right: 16,
              top: 120,
              child: SafeArea(
                child: FadeTransition(
                  opacity: _animController,
                  child: _buildMapControls(),
                ),
              ),
            ),

            // Stats display (left side)
            Positioned(
              left: 16,
              bottom: 220,
              child: FadeTransition(
                opacity: _animController,
                child: _buildSpeedDisplay(),
              ),
            ),
            
            // Step counter display (right side)
            Positioned(
              right: 16,
              bottom: 220,
              child: BlocBuilder<LocationBloc, LocationState>(
                builder: (context, state) {
                  if (state is! LocationTracking) return SizedBox.shrink();
                  return Container(
                    width: 80,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_walk, color: Color(0xFF2196F3), size: 22),
                      SizedBox(height: 2),
                      Text(
                        '$_advancedSteps',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'steps',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_displayedMotionType != MotionType.stationary) ...[
                        SizedBox(height: 3),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _displayedMotionType == MotionType.running ? Colors.red.shade100 :
                                    _displayedMotionType == MotionType.jogging ? Colors.orange.shade100 :
                                    Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _displayedMotionType.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: _displayedMotionType == MotionType.running ? Colors.red.shade700 :
                                      _displayedMotionType == MotionType.jogging ? Colors.orange.shade700 :
                                      Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  );
                },
              ),
            ),
          
            // Simplified tracking button
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _animController,
                child: _buildTrackingButton(),
              ),
            ),
          
            // Countdown overlay
            if (_showCountdown)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Text(
                    _countdown.toString(),
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          
            // End session countdown overlay
            if (_showEndAnimation)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stop_circle_outlined,
                      size: 80,
                      color: Colors.red,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Ending Session',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _endCountdown.toString(),
                      style: TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalStatsBar() {
    return BlocBuilder<GameBloc, GameState>(builder: (context, gameState) {
      return BlocBuilder<LocationBloc, LocationState>(builder: (context, locationState) {
        if (gameState is! GameLoaded) return SizedBox.shrink();
        
        final isTracking = locationState is LocationTracking;
        final distance = isTracking ? locationState.totalDistance / 1000 : gameState.stats.totalDistanceKm;
        
        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isTracking ? Color(0xFF2196F3) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (isTracking)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${distance.toStringAsFixed(2)} km',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              if (!isTracking)
                _buildStatItem(
                  '${distance.toStringAsFixed(1)} km',
                  'Distance',
                  isTracking,
                ),
              if (isTracking && _advancedSteps > 0) ...[
                Container(
                  width: 1, 
                  height: 30, 
                  color: Colors.white30,
                ),
                Row(
                  children: [
                    Icon(Icons.directions_walk_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '$_advancedSteps',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
              Container(
                width: 1, 
                height: 30, 
                color: isTracking ? Colors.white30 : Colors.grey.shade300,
              ),
              _buildStatItem(
                '${gameState.stats.territoriesCaptured}',
                'Territories',
                isTracking,
              ),
              Container(
                width: 1, 
                height: 30, 
                color: isTracking ? Colors.white30 : Colors.grey.shade300,
              ),
              _buildStatItem(
                '${gameState.stats.totalPoints}',
                'Points',
                isTracking,
              ),
            ],
          ),
        );
      });
    });
  }

  Widget _buildStatItem(String value, String label, bool isTracking) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isTracking ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isTracking ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingButton() {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        final isTracking = state is LocationTracking;
        
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active tracking info
              if (isTracking)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tracking: ${(state.totalDistance / 1000).toStringAsFixed(2)} km',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Animated control buttons (Start -> Pause/End)
              _buildControlButtons(isTracking),
            ],
          ),
        );
      },
    );
  }
  
  void _updateRoutePolyline(LocationTracking state) {
    if (state.routePoints.length < 2) {
      print('⚠️ Route update skipped: need at least 2 points, have ${state.routePoints.length}');
      return;
    }
    
    final points = state.routePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Color(0xFF2196F3), // Bright blue for visibility
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    });
    
    print('✅ Route updated: ${points.length} points, ${(state.totalDistance / 1000).toStringAsFixed(2)} km');
  }
  
  void _updateStartPointMarker(LocationTracking state) {
    if (state.routePoints.isEmpty) return;
    
    final startPoint = state.routePoints.first;
    final currentPoint = state.currentPosition;
    
    // Calculate distance to start
    _distanceToStart = _calculateDistanceBetweenPoints(startPoint, currentPoint);
    
    // Create start point circle marker
    setState(() {
      Color circleColor = Colors.green;
      double radius = 50; // 50 meters
      
      // Change color based on distance to start
      if (_distanceToStart < 100) {
        circleColor = Colors.greenAccent; // Very close!
        radius = 100;
      } else if (_distanceToStart < 200) {
        circleColor = Colors.yellow; // Getting close
        radius = 75;
      }
      
      _startPointCircle = Circle(
        circleId: CircleId('start_point'),
        center: LatLng(startPoint.latitude, startPoint.longitude),
        radius: radius,
        fillColor: circleColor.withOpacity(0.3),
        strokeColor: circleColor,
        strokeWidth: 3,
      );
    });
    
    // Loop closure haptic feedback (only once per approach)
    if (_distanceToStart < 100 && !_hasGivenCloseLoopFeedback && state.routePoints.length > 10) {
      _hasGivenCloseLoopFeedback = true;
      HapticFeedback.heavyImpact();
      // Audio removed - file not available
      
      // Calculate estimated area for user feedback
      _estimatedAreaSqMeters = _calculatePolygonArea(state.routePoints);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Loop ready! ~${_formatArea(_estimatedAreaSqMeters)} capturable',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (_distanceToStart >= 150) {
      // Reset feedback when user moves away from start
      _hasGivenCloseLoopFeedback = false;
    }
  }
  
  // Calculate polygon area using industry-grade spherical geometry
  double _calculatePolygonArea(List<dynamic> points) {
    if (points.length < 3) return 0;
    
    // Convert to LatLng list
    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    
    // Use industry-grade area calculation with spherical excess for large polygons
    return PolygonArea.calculateArea(latLngs);
  }
  
  // Format area for display
  String _formatArea(double sqMeters) {
    if (sqMeters < 1000) {
      return '${sqMeters.toStringAsFixed(0)} m²';
    } else if (sqMeters < 10000) {
      return '${(sqMeters / 1000).toStringAsFixed(1)}k m²';
    } else {
      return '${(sqMeters / 10000).toStringAsFixed(2)} hectares';
    }
  }
  
  void _updateTerritoryPolygons(List<app.Territory> territories) {
    // Aggressive caching - don't process if already loaded
    if (territories.isEmpty || territories.length == _lastLoadedTerritoryCount) {
      return; // Skip - already processed
    }
    
    // Load and display all captured territories as filled areas
    // TODO: Get current user ID from auth
    const currentUserId = 'current_user';
    
    setState(() {
      _polygons.clear();
      _territoryMarkers.clear();
      
      // Group territories by owner to create filled areas
      Map<String, List<app.Territory>> territoriesByOwner = {};
      for (final territory in territories) {
        if (territory.ownerId != null) {
          territoriesByOwner.putIfAbsent(territory.ownerId!, () => []).add(territory);
        }
      }
      
      // Create filled area for each owner's territories
      for (final ownerId in territoriesByOwner.keys) {
        final ownerTerritories = territoriesByOwner[ownerId]!;
        if (ownerTerritories.isEmpty) continue;
        
        // Collect all boundary points from all territories
        List<LatLng> allPoints = [];
        for (final territory in ownerTerritories) {
          for (final coord in territory.boundary) {
            allPoints.add(LatLng(coord[0], coord[1]));
          }
        }
        
        if (allPoints.isEmpty) continue;
        
        // Determine color based on ownership
        Color fillColor;
        Color strokeColor;
        String ownerName = ownerTerritories.first.ownerName ?? 'Unknown';
        
        if (ownerId == currentUserId) {
          // Your territory - green
          fillColor = Color(0xFF4CAF50).withOpacity(0.25);
          strokeColor = Color(0xFF4CAF50);
        } else {
          // Other player's territory - red
          fillColor = Color(0xFFE53935).withOpacity(0.25);
          strokeColor = Color(0xFFE53935);
        }
        
        // Calculate center for marker
        double sumLat = 0, sumLng = 0;
        for (final point in allPoints) {
          sumLat += point.latitude;
          sumLng += point.longitude;
        }
        final centerLat = sumLat / allPoints.length;
        final centerLng = sumLng / allPoints.length;
        
        // Add filled area polygon
        _polygons.add(
          Polygon(
            polygonId: PolygonId('territory_$ownerId'),
            points: allPoints,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: 2,
          ),
        );
        
        // Add owner marker
        _territoryMarkers.add(
          Marker(
            markerId: MarkerId('label_$ownerId'),
            position: LatLng(centerLat, centerLng),
            infoWindow: InfoWindow(
              title: ownerName,
              snippet: '${ownerTerritories.length} territories',
            ),
          ),
        );
      }
    });
  }
  
  void _showTerritoryInfo(app.Territory territory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Territory Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${territory.hexId}'),
            SizedBox(height: 8),
            Text('Owner: ${territory.ownerName ?? "Unclaimed"}'),
            SizedBox(height: 8),
            Text('Captures: ${territory.captureCount}'),
            SizedBox(height: 8),
            Text('Points: ${territory.points}'),
            if (territory.lastBattleAt != null) ...[
              SizedBox(height: 8),
              Text('Last Battle: ${_formatTime(territory.lastBattleAt!)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
  
  void _captureTerritoriesRealTime(LocationTracking state) {
    // DISABLED: Individual hex capture removed - only loop-based capture is active
    // Territory capture now only happens when you complete a closed loop
    // and press the stop button
    return;
  }
  
  void _updateStatsRealTime(LocationTracking state) {
    final currentDistanceKm = state.totalDistance / 1000;
    final distanceDelta = currentDistanceKm - _lastDistanceUpdate;
    
    print('🔍 Distance check: current=${currentDistanceKm.toStringAsFixed(4)} km, last=${_lastDistanceUpdate.toStringAsFixed(4)} km, delta=${distanceDelta.toStringAsFixed(4)} km');
    
    // REAL-TIME: Update when distance changes by at least 5 meters
    if (distanceDelta >= 0.005) {
      _lastDistanceUpdate = currentDistanceKm;
      
      // Update distance in GameBloc
      print('📊 Updating GameBloc: +${distanceDelta.toStringAsFixed(3)} km');
      context.read<GameBloc>().add(UpdateDistance(distanceDelta));
      
      // Award points based on distance (100 points per km)
      final pointsDelta = (distanceDelta * 100).round();
      if (pointsDelta > 0) {
        context.read<GameBloc>().add(AddPoints(pointsDelta));
      }
      
      // Update calories (60 cal per km)
      final caloriesDelta = (distanceDelta * 60).round();
      if (caloriesDelta > 0) {
        context.read<GameBloc>().add(AddCalories(caloriesDelta));
      }
    }
    
    // Update notification only when distance changes by 0.05 km (50 meters) - prevent spam
    final distanceKm = state.totalDistance / 1000;
    if ((distanceKm - _lastNotificationDistance).abs() >= 0.05) {
      _updateBackgroundNotification(state);
      _lastNotificationDistance = distanceKm;
    }
  }
  
  void _updateBackgroundNotification(LocationTracking state) {
    // Determine speed category from current speed
    String speedCategory = 'Still';
    if (_currentSpeed > 0 && _currentSpeed < 6) speedCategory = 'Walking';
    else if (_currentSpeed >= 6 && _currentSpeed < 10) speedCategory = 'Jogging';
    else if (_currentSpeed >= 10) speedCategory = 'Running';
    
    // Use motion detection if available
    if (_motionType != MotionType.stationary) {
      speedCategory = _motionType.toString().split('.').last.toUpperCase();
    }
    
    // Update with CURRENT SESSION data (event-driven, no timer)
    BackgroundTrackingService.updateNotification(
      distance: state.totalDistance / 1000,
      territories: _currentSessionTerritories, // Show territories captured THIS session
      speed: speedCategory,
    );
  }
  
  // ============================================================================
  // INDUSTRY-GRADE TERRITORY CAPTURE WITH ANTI-CHEAT VALIDATION
  // ============================================================================
  /// Captures territories from closed loop route.
  /// Returns the number of territories captured (for use in session summary).
  int _captureTerritoriesFromRoute() {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is! LocationTracking) return 0;
    
    // TODO: Get current user info from auth
    const currentUserId = 'current_user';
    const currentUserName = 'Runner'; // Replace with actual username
    
    if (locationState.routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No route recorded. Start tracking to capture territories!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return 0;
    }
    
    // Require minimum distance before allowing capture
    final distanceKm = locationState.totalDistance / 1000;
    if (distanceKm < 0.1) { // Must move at least 100 meters
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Move at least 100 meters to capture territories!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return 0;
    }
    
    // =========================================================================
    // ANTI-CHEAT VALIDATION - Detect GPS spoofing and impossible movements
    // =========================================================================
    // Convert route points to the format expected by AntiCheatValidator
    final routeWithTimestamps = locationState.routePoints
        .map((p) => (position: LatLng(p.latitude, p.longitude), timestamp: p.timestamp))
        .toList();
    
    final validationResult = AntiCheatValidator.validateRoute(routeWithTimestamps);
    if (!validationResult.isValid) {
      print('⛔ ANTI-CHEAT: Route failed validation - ${validationResult.violation}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Route validation failed: ${validationResult.violation}')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
      return 0;
    }
    print('✅ ANTI-CHEAT: Route passed validation');
    
    // Calculate actual route perimeter to detect excessive wandering
    double routePerimeter = 0;
    for (int i = 0; i < locationState.routePoints.length - 1; i++) {
      routePerimeter += _calculateDistanceBetweenPoints(
        locationState.routePoints[i],
        locationState.routePoints[i + 1],
      );
    }
    
    // Warn if route is very inefficient (possible figure-8 or excessive crossing)
    if (routePerimeter > distanceKm * 1000 * 1.5) {
      print('⚠️ Route perimeter ($routePerimeter m) is much larger than distance traveled (${distanceKm * 1000} m)');
      // Note: This is just a warning, not blocking capture
    }
    
    final Set<String> capturedHexIds = {};
    final List<app.Territory> newTerritories = [];
    final List<app.Territory> recapturedTerritories = [];
    
    // Get existing territories to check for recaptures
    final territoryState = context.read<TerritoryBloc>().state;
    final existingTerritories = territoryState is TerritoryLoaded 
        ? {for (var t in territoryState.territories) t.hexId: t}
        : <String, app.Territory>{};
    
    print('Processing ${locationState.routePoints.length} route points...');
    
    // Convert route points to LatLng for polygon operations
    final rawRouteLatLngs = locationState.routePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    
    // SIMPLIFY route to reduce GPS jitter and improve polygon quality
    // Epsilon of 3 meters - removes noise while preserving shape
    final routeLatLngs = _simplifyRoute(rawRouteLatLngs, 3.0);
    print('📊 Route simplified: ${rawRouteLatLngs.length} → ${routeLatLngs.length} points');
    
    // Check if route forms a closed loop (start and end are close)
    final distanceToStart = _calculateDistanceBetweenPoints(
      locationState.routePoints.first,
      locationState.routePoints.last,
    );
    
    final isClosedLoop = locationState.routePoints.length >= 3 && distanceToStart < 100;
    
    print('🔍 Loop check: ${locationState.routePoints.length} points, distance to start: ${distanceToStart.toStringAsFixed(1)}m, closed: $isClosedLoop');
    
    if (isClosedLoop) {
      print('🎯 Closed loop detected! Capturing ENTIRE area inside polygon...');
      
      // Get bounding box of the route first
      double minLat = routeLatLngs.first.latitude;
      double maxLat = routeLatLngs.first.latitude;
      double minLng = routeLatLngs.first.longitude;
      double maxLng = routeLatLngs.first.longitude;
      
      for (final point in routeLatLngs) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      
      // Validate polygon has meaningful area (not a sliver/line)
      // Calculate area in meters, not degrees
      const double metersPerDegreeLat = 111000.0;
      final avgLat = (minLat + maxLat) / 2;
      final metersPerDegreeLng = metersPerDegreeLat * cos(avgLat * pi / 180);
      
      final heightMeters = (maxLat - minLat) * metersPerDegreeLat;
      final widthMeters = (maxLng - minLng) * metersPerDegreeLng;
      final boundingAreaSqMeters = heightMeters * widthMeters;
      
      print('📐 Bounding box: ${widthMeters.toStringAsFixed(1)}m x ${heightMeters.toStringAsFixed(1)}m = ${boundingAreaSqMeters.toStringAsFixed(0)} m²');
      
      if (boundingAreaSqMeters < 100) { // 10m x 10m = 100 m² minimum
        print('⚠️ Loop too small to capture area: ${boundingAreaSqMeters.toStringAsFixed(0)} m² < 100 m²');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loop area too small! Current: ${boundingAreaSqMeters.toStringAsFixed(0)} m² (need 100+ m²)'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        return 0;
      }
      
      // Use much finer granularity for territory scanning - 20 meters
      final latStep = 0.00018; // ~20 meters latitude
      // Longitude degrees vary by latitude: adjust for accurate spacing (avgLat already calculated above)
      final lngStep = 0.00018 / cos(avgLat * pi / 180); // Compensate for latitude
      
      int scannedPoints = 0;
      int capturedPoints = 0;
      
      for (double lat = minLat; lat <= maxLat; lat += latStep) {
        for (double lng = minLng; lng <= maxLng; lng += lngStep) {
          scannedPoints++;
          if (_isPointInPolygon(LatLng(lat, lng), routeLatLngs)) {
            capturedPoints++;
            final hexId = TerritoryGridHelper.getHexId(lat, lng);
            
            if (!capturedHexIds.contains(hexId)) {
              capturedHexIds.add(hexId);
              
              // Check if territory already exists (recapture scenario)
              final existingTerritory = existingTerritories[hexId];
              
              if (existingTerritory != null) {
                // Recapture from another user or reinforce own territory
                if (existingTerritory.ownerId != currentUserId) {
                  final recaptured = existingTerritory.recaptureBy(currentUserId, currentUserName);
                  recapturedTerritories.add(recaptured);
                  context.read<TerritoryBloc>().add(CaptureTerritoryEvent(recaptured));
                }
                // Skip if already owned by current user
              } else {
                // New territory capture
                // Note: createTerritory will compute proper hex center from lat/lng
                final territory = TerritoryGridHelper.createTerritory(
                  lat, lng,
                  ownerId: currentUserId,
                  ownerName: currentUserName,
                );
                newTerritories.add(territory);
                context.read<TerritoryBloc>().add(CaptureTerritoryEvent(territory));
              }
            }
          }
        }
      }
      
      print('📊 Scanned $scannedPoints points, $capturedPoints inside polygon, ${capturedHexIds.length} unique territories');
    } else {
      print('⚠️ Path not closed - distance to start: ${distanceToStart.toStringAsFixed(1)}m (need < 100m)');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Return to your starting point to capture the enclosed area!\nCurrent distance: ${distanceToStart.toStringAsFixed(0)}m (need < 100m)'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      return 0; // Don't capture anything if not a closed loop
    }
    
    // Award points based on territories ONLY (distance points already awarded in real-time)
    final totalNewTerritories = newTerritories.length + recapturedTerritories.length;
    if (totalNewTerritories > 0) {
      final newTerritoryPoints = newTerritories.length * 50;
      final recapturePoints = recapturedTerritories.length * 75; // Bonus for recapture
      final totalTerritoryPoints = newTerritoryPoints + recapturePoints;
      
      context.read<GameBloc>().add(AddPoints(totalTerritoryPoints));
      
      // Fire TerritoryCapture event for each territory
      for (var i = 0; i < totalNewTerritories; i++) {
        context.read<GameBloc>().add(TerritoryCapture());
      }
      
      // Update session territories count
      setState(() {
        _currentSessionTerritories = totalNewTerritories;
      });
    }
    
    // NOTE: Distance, calories, and distance points are tracked in REAL-TIME
    // via _updateStatsRealTime() - do NOT duplicate them here!
    final distancePoints = (distanceKm * 100).round();
    
    print('✅ Captured ${newTerritories.length} new, ${recapturedTerritories.length} recaptured (${isClosedLoop ? "AREA" : "PATH"}), ${distanceKm.toStringAsFixed(2)} km');
    
    // No notifications spam - area will be shown visually on map
    
    // Return total territories captured this session
    return totalNewTerritories;
  }
  
  // Fill captured area with transparent color
  // Shows EXACTLY what you walked: circle = filled circle, zigzag = filled zigzag
  void _showCapturedArea(List<LatLng> routePoints) {
    if (routePoints.length < 3) return;
    
    // Generate unique ID for this captured area using timestamp
    final areaId = DateTime.now().millisecondsSinceEpoch.toString();
    
    setState(() {
      // DON'T clear existing polygons - just add the new one!
      // _polygons.clear();  // REMOVED - this was deleting previous captures
      // _territoryMarkers.clear();  // REMOVED
      
      // Fill the area you walked with transparent green
      _polygons.add(
        Polygon(
          polygonId: PolygonId('captured_area_$areaId'),
          points: routePoints,
          fillColor: Color(0xFF4CAF50).withOpacity(0.25), // Transparent green fill
          strokeColor: Color(0xFF4CAF50),
          strokeWidth: 2,
        ),
      );
      
      // Show username in center of captured area
      if (routePoints.isNotEmpty) {
        double sumLat = 0, sumLng = 0;
        for (final point in routePoints) {
          sumLat += point.latitude;
          sumLng += point.longitude;
        }
        
        _territoryMarkers.add(
          Marker(
            markerId: MarkerId('username_label_$areaId'),
            position: LatLng(sumLat / routePoints.length, sumLng / routePoints.length),
            infoWindow: InfoWindow(
              title: 'Runner',
              snippet: '${(_estimatedAreaSqMeters / 1000).toStringAsFixed(2)} km²',
            ),
          ),
        );
      }
    });
    
    print('✅ Filled captured area with username');
  }
  
  // Helper: Calculate distance between two positions using Vincenty formula
  double _calculateDistanceBetweenPoints(dynamic pos1, dynamic pos2) {
    return GeodesicCalculator.vincentyDistance(
      LatLng(pos1.latitude, pos1.longitude),
      LatLng(pos2.latitude, pos2.longitude),
    );
  }
  
  // ============================================================================
  // INDUSTRY-GRADE POINT-IN-POLYGON (WINDING NUMBER WITH NUMERICAL STABILITY)
  // ============================================================================
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    // Use industry-grade winding number algorithm with epsilon tolerance
    return PointInPolygon.isInside(point, polygon);
  }
  
  // ============================================================================
  // INDUSTRY-GRADE ROUTE SIMPLIFICATION (RAMER-DOUGLAS-PEUCKER WITH GEODESIC DISTANCE)
  // ============================================================================
  List<LatLng> _simplifyRoute(List<LatLng> points, double epsilon) {
    // Use industry-grade Douglas-Peucker with proper geodesic distance
    return RouteSimplifier.simplify(points, epsilon);
  }
  
  // ============================================================================
  // INDUSTRY-GRADE GEODESIC DISTANCE (VINCENTY FORMULA)
  // ============================================================================
  double _calculateGeodesicDistance(LatLng p1, LatLng p2) {
    // Use Vincenty formula for WGS84 ellipsoid accuracy
    return GeodesicCalculator.vincentyDistance(p1, p2);
  }
  
  // ============================================================================
  // INDUSTRY-GRADE POLYGON AREA (SPHERICAL GEOMETRY)
  // ============================================================================
  double _calculatePolygonAreaSqMeters(List<LatLng> polygon) {
    return PolygonArea.calculateArea(polygon);
  }

  // Map control buttons
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildControlButton(
          icon: Icons.threed_rotation,
          label: '3D',
          isActive: _is3DMode,
          onTap: _toggle3DMode,
        ),
        SizedBox(height: 8),
        _buildControlButton(
          icon: Icons.layers,
          label: 'View',
          isActive: _currentMapType != MapType.normal,
          onTap: _toggleMapType,
        ),
      ],
    );
  }
  
  // Simulation toggle button
  Widget _buildSimulationToggle() {
    // Only show when tracking is stopped
    if (_trackingState != TrackingState.stopped) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _useSimulation ? Color(0xFF2196F3) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _useSimulation ? Icons.computer : Icons.gps_fixed,
            color: _useSimulation ? Colors.white : Colors.black87,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            _useSimulation ? 'Simulate' : 'Real GPS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _useSimulation ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(width: 8),
          Switch(
            value: _useSimulation,
            onChanged: (value) {
              setState(() {
                _useSimulation = value;
              });
              print("${value ? '🎮' : '📍'} Simulation mode: ${value ? 'ON' : 'OFF'}");
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.blue.shade300,
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.black87,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Speed display with step counter
  Widget _buildSpeedDisplay() {
    // Show if tracking and either moving OR has steps
    final locationState = context.read<LocationBloc>().state;
    final isTracking = locationState is LocationTracking;
    
    if (!isTracking && _currentSpeed == 0.0) return SizedBox.shrink();
    
    // Determine speed category
    String category;
    Color speedColor;
    
    if (_currentSpeed < 6) {
      category = 'Walking';
      speedColor = Colors.blue;
    } else if (_currentSpeed < 10) {
      category = 'Jogging';
      speedColor = Colors.orange;
    } else {
      category = 'Running';
      speedColor = Colors.red;
    }
    
    return Container(
      width: 120,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: speedColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 5),
              Text(
                category,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 3),
          Text(
            '${_currentSpeed.toStringAsFixed(1)} km/h',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          // Distance to start indicator
          if (_distanceToStart < double.infinity) ...[
            SizedBox(height: 6),
            Divider(height: 1),
            SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.my_location,
                  size: 12,
                  color: _distanceToStart < 100 
                      ? Colors.green 
                      : _distanceToStart < 200 
                          ? Colors.orange 
                          : Colors.grey,
                ),
                SizedBox(width: 4),
                Text(
                  '${_distanceToStart.toStringAsFixed(0)}m',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _distanceToStart < 100 
                        ? Colors.green 
                        : _distanceToStart < 200 
                            ? Colors.orange 
                            : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          // Estimated capturable area (when close enough to complete loop)
          if (_estimatedAreaSqMeters > 0 && _distanceToStart < 100) ...[
            SizedBox(height: 6),
            Divider(height: 1),
            SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.crop_square,
                  size: 12,
                  color: Colors.purple,
                ),
                SizedBox(width: 4),
                Text(
                  _formatArea(_estimatedAreaSqMeters),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Toggle 3D mode
  void _toggle3DMode() {
    setState(() {
      _is3DMode = !_is3DMode;
    });
    
    if (_mapController != null) {
      final locationState = context.read<LocationBloc>().state;
      LatLng? currentPosition;
      
      if (locationState is LocationTracking && locationState.routePoints.isNotEmpty) {
        final lastPoint = locationState.routePoints.last;
        currentPosition = LatLng(lastPoint.latitude, lastPoint.longitude);
      } else if (locationState is LocationIdle && locationState.lastPosition != null) {
        currentPosition = LatLng(
          locationState.lastPosition!.latitude,
          locationState.lastPosition!.longitude,
        );
      }
      
      if (currentPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentPosition,
              zoom: _is3DMode ? 18 : 15,
              tilt: _is3DMode ? 45 : 0,
              bearing: _is3DMode ? 45 : 0,
            ),
          ),
        );
      }
    }
  }

  // Toggle map type
  void _toggleMapType() {
    setState(() {
      if (_currentMapType == MapType.normal) {
        _currentMapType = MapType.hybrid;
      } else if (_currentMapType == MapType.hybrid) {
        _currentMapType = MapType.satellite;
      } else {
        _currentMapType = MapType.normal;
      }
    });
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ULTRA-ADVANCED SPEED CALCULATION
  /// Uses Weighted Moving Average with outlier rejection
  /// ═══════════════════════════════════════════════════════════════════════════
  void _calculateSpeed(LocationTracking state) {
    if (state.routePoints.length < 2) {
      setState(() => _currentSpeed = 0.0);
      return;
    }
    
    final now = DateTime.now();
    
    // Throttle to every 1.5 seconds for smooth updates
    if (_lastSpeedUpdate != null && 
        now.difference(_lastSpeedUpdate!).inMilliseconds < 1500) {
      return;
    }
    
    // Get more points for better averaging (up to 8)
    final numPoints = min(8, state.routePoints.length);
    final recentPoints = state.routePoints.sublist(state.routePoints.length - numPoints);
    
    if (recentPoints.length < 2) return;
    
    // Calculate segment speeds with weights (more recent = higher weight)
    final segmentSpeeds = <double>[];
    final weights = <double>[];
    
    for (int i = 1; i < recentPoints.length; i++) {
      final p1 = recentPoints[i - 1];
      final p2 = recentPoints[i];
      
      final distance = geo.Geolocator.distanceBetween(
        p1.latitude, p1.longitude,
        p2.latitude, p2.longitude,
      );
      
      final timeDiff = p2.timestamp.difference(p1.timestamp).inMilliseconds / 1000.0;
      
      if (timeDiff > 0 && timeDiff < 30) { // Reject segments with invalid time
        final speed = distance / timeDiff; // m/s
        
        // Outlier rejection: ignore speeds > 15 m/s (54 km/h)
        if (speed <= 15.0) {
          segmentSpeeds.add(speed);
          // Weight: more recent segments get exponentially higher weight
          weights.add(pow(1.5, i.toDouble()).toDouble());
        }
      }
    }
    
    if (segmentSpeeds.isEmpty) {
      setState(() {
        _currentSpeed = 0.0;
        _lastSpeedUpdate = now;
      });
      return;
    }
    
    // Calculate weighted average speed
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for (int i = 0; i < segmentSpeeds.length; i++) {
      weightedSum += segmentSpeeds[i] * weights[i];
      totalWeight += weights[i];
    }
    
    final avgSpeedMs = totalWeight > 0 ? weightedSum / totalWeight : 0.0;
    final avgSpeedKmh = avgSpeedMs * 3.6;
    
    // Apply exponential smoothing with current speed
    final alpha = 0.4; // Smoothing factor
    final smoothedSpeed = alpha * avgSpeedKmh + (1 - alpha) * _currentSpeed;
    
    setState(() {
      _currentSpeed = smoothedSpeed.clamp(0, 54); // Max 54 km/h (15 m/s)
      _lastSpeedUpdate = now;
    });
  }
  
  // Animated control buttons (Start -> Pause/End + Home)
  Widget _buildControlButtons(bool isTracking) {
    return AnimatedBuilder(
      animation: _buttonAnimController,
      builder: (context, child) {
        final isExpanded = _trackingState == TrackingState.started || _trackingState == TrackingState.paused;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Home button (always visible)
            GestureDetector(
              onTap: () {
                if (widget.onNavigateHome != null) {
                  widget.onNavigateHome!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 28,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(width: 20),
            
            // Pause button (only visible when tracking started)
            if (isExpanded) ...[
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: isExpanded ? 70 : 0,
                child: AnimatedOpacity(
                  opacity: isExpanded ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _handlePause,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _trackingState == TrackingState.paused ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_trackingState == TrackingState.paused ? Colors.green : Colors.orange).withOpacity(0.3),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _trackingState == TrackingState.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 20),
            ],
            
            // Main button (Start/End)
            GestureDetector(
              onTap: () {
                if (_trackingState == TrackingState.stopped) {
                  _handleStart(context);
                }
              },
              onLongPressStart: (_) {
                if (_trackingState != TrackingState.stopped) {
                  _startHoldTimer(context);
                }
              },
              onLongPressEnd: (_) {
                _cancelHoldTimer();
              },
              onLongPressCancel: () {
                _cancelHoldTimer();
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress indicator
                  if (_isHoldingEnd)
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _holdProgress,
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  // Button
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _trackingState == TrackingState.stopped ? Colors.black87 : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_trackingState == TrackingState.stopped ? Colors.black87 : Colors.red).withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _trackingState == TrackingState.stopped ? Icons.play_arrow_rounded : Icons.stop_rounded,
                      size: 35,
                  color: Colors.white,
                ),
              ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _startHoldTimer(BuildContext context) {
    setState(() {
      _isHoldingEnd = true;
      _holdProgress = 0.0;
    });
    
    const updateInterval = Duration(milliseconds: 50);
    final totalSteps = _holdDuration.inMilliseconds / updateInterval.inMilliseconds;
    var currentStep = 0;
    
    _holdTimer = Timer.periodic(updateInterval, (timer) {
      currentStep++;
      final progress = currentStep / totalSteps;
      
      if (progress >= 1.0) {
        timer.cancel();
        setState(() {
          _isHoldingEnd = false;
          _holdProgress = 0.0;
        });
        _handleEnd(context);
      } else {
        setState(() {
          _holdProgress = progress;
        });
      }
    });
  }
  
  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    setState(() {
      _isHoldingEnd = false;
      _holdProgress = 0.0;
    });
  }

  void _handleStart(BuildContext context) {
    setState(() {
      _trackingState = TrackingState.started;
    });
    _buttonAnimController.forward();
    _startCountdown(context);
  }

  void _handlePause() {
    if (_trackingState == TrackingState.started) {
      // Pause tracking
      setState(() {
        _trackingState = TrackingState.paused;
        _pauseStartTime = DateTime.now();
      });
      
      // Pause location tracking
      context.read<LocationBloc>().add(StopLocationTracking());
      _motionDetection.stopDetection();
      BackgroundTrackingService.stopTracking();
      
      print('⏸️ TRACKING PAUSED');
    } else if (_trackingState == TrackingState.paused) {
      // Resume tracking
      setState(() {
        if (_pauseStartTime != null) {
          _pausedDuration += DateTime.now().difference(_pauseStartTime!);
          _pauseStartTime = null;
        }
        _trackingState = TrackingState.started;
      });
      
      // Resume location tracking
      context.read<LocationBloc>().add(StartLocationTracking());
      _motionDetection.startDetection();
      
      final locationState = context.read<LocationBloc>().state;
      final distance = locationState is LocationTracking ? locationState.totalDistance / 1000 : 0.0;
      final territoriesState = context.read<TerritoryBloc>().state;
      final territoriesCount = territoriesState is TerritoryLoaded ? territoriesState.territories.length : 0;
      
      BackgroundTrackingService.startTracking(
        currentDistance: distance,
        territoriesCount: territoriesCount,
      );
      
      print('▶️ TRACKING RESUMED');
    }
  }

  void _handleEnd(BuildContext context) {
    // Start end countdown animation
    setState(() {
      _showEndAnimation = true;
      _endCountdown = 3;
    });
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endCountdown > 0) {
        // Audio removed - file not available
        setState(() => _endCountdown--);
      } else {
        timer.cancel();
        setState(() => _showEndAnimation = false);
        _completeEndSession(context);
      }
    });
  }

  Future<void> _completeEndSession(BuildContext context) async {
    // Stop tracking and show summary
    final locationState = context.read<LocationBloc>().state;
    final distance = locationState is LocationTracking ? locationState.totalDistance / 1000 : 0.0;
    
    // Calculate actual tracking duration (excluding paused time)
    final totalDuration = _trackingStartTime != null 
        ? DateTime.now().difference(_trackingStartTime!) 
        : Duration.zero;
    final activeDuration = totalDuration - _pausedDuration;
    
    final sessionSteps = _steps - _sessionStartSteps;
    final avgSpeed = activeDuration.inSeconds > 0 
        ? (distance / (activeDuration.inSeconds / 3600)) 
        : 0.0;
    
    print('=== ENDING TRACKING ===');
    print('Distance: $distance km');
    print('Active Duration: $activeDuration');
    print('Paused Duration: $_pausedDuration');
    
    context.read<LocationBloc>().add(StopLocationTracking());
    _motionDetection.stopDetection();
    
    // Capture territories from closed loop - now returns count directly (no race condition!)
    final newTerritoryCount = _captureTerritoriesFromRoute();
    final pointsEarned = newTerritoryCount * 50; // 50 points per territory
    
    print('New territories captured: $newTerritoryCount');
    print('Points earned: $pointsEarned');
    
    // Capture route points for display
    final routePoints = locationState is LocationTracking
        ? locationState.routePoints.map((p) => LatLng(p.latitude, p.longitude)).toList()
        : <LatLng>[];
    
    // Show captured area as single filled polygon
    if (routePoints.length >= 3) {
      _showCapturedArea(routePoints);
    }
    
    setState(() {
      _trackingState = TrackingState.stopped;
      _currentSpeed = 0.0;
      _capturedHexIds.clear();
      _lastDistanceUpdate = 0.0;
      _trackingStartTime = null;
      _sessionStartSteps = 0;
      _startPointCircle = null;
      _distanceToStart = double.infinity;
      _advancedSteps = 0;
      _motionType = MotionType.stationary;
      _pausedDuration = Duration.zero;
      _pauseStartTime = null;
      _hasGivenCloseLoopFeedback = false;
      _estimatedAreaSqMeters = 0.0;
    });
    
    _buttonAnimController.reverse();
    BackgroundTrackingService.stopTracking();
    
    // Save activity to history
    await _saveActivityToHistory(
      locationState: locationState,
      distance: distance,
      activeDuration: activeDuration,
      avgSpeed: avgSpeed,
      sessionSteps: sessionSteps,
      territoriesCount: newTerritoryCount,
      pointsEarned: pointsEarned,
      routePoints: routePoints,
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutSummaryScreen(
          distanceKm: distance,
          territoriesCaptured: newTerritoryCount,
          pointsEarned: pointsEarned,
          duration: activeDuration,
          avgSpeed: avgSpeed,
          steps: sessionSteps,
          routePoints: routePoints,
          territories: _polygons.isNotEmpty ? _polygons : null,
          workoutDate: _trackingStartTime,
        ),
      ),
    );
  }

  // Picture-in-Picture Mini View
  void _startCountdown(BuildContext context) {
    setState(() {
      _showCountdown = true;
      _countdown = 3;
    });
    
    print('⏱️ START COUNTDOWN INITIATED');
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        // Audio removed - file not available
        setState(() => _countdown--);
        print('⏱️ Countdown: $_countdown');
      } else {
        timer.cancel();
        setState(() => _showCountdown = false);
        
        print('🚀 STARTING TRACKING NOW!');
        
        // Start actual tracking with simulation mode based on toggle
        context.read<LocationBloc>().add(StartLocationTracking(useSimulation: _useSimulation));
        print('${_useSimulation ? "🎮" : "📍"} LocationBloc: StartLocationTracking (${_useSimulation ? "SIMULATION" : "REAL GPS"} MODE) event sent');
        
        // Start ADVANCED motion detection
        _motionDetection.startDetection();
        _motionDetection.resetSteps();
        print('👟 Motion detection started');
        
        _capturedHexIds.clear();
        _lastDistanceUpdate = 0.0;
        _lastNotificationDistance = 0.0;
        _currentSessionTerritories = 0; // Reset session territories
        _trackingStartTime = DateTime.now();
        _sessionStartSteps = _steps;
        
        BackgroundTrackingService.startTracking(
          currentDistance: 0.0,
          territoriesCount: 0,
        );
        
        print('🚀 ADVANCED TRACKING STARTED - Real-time GPS + Motion Detection Active!');
        print('🔊 Waiting for location updates...');
      }
    });
  }
  
  // Capture map screenshot
  Future<String?> _captureMapScreenshot() async {
    try {
      if (_mapController == null) return null;
      
      final imageBytes = await _mapController!.takeSnapshot();
      if (imageBytes == null) return null;
      
      final base64Image = base64Encode(imageBytes);
      print('📸 Map screenshot captured (${imageBytes.length} bytes)');
      return base64Image;
    } catch (e) {
      print('❌ Error capturing map screenshot: $e');
      return null;
    }
  }

  // Save completed workout to history
  Future<void> _saveActivityToHistory({
    required LocationState locationState,
    required double distance,
    required Duration activeDuration,
    required double avgSpeed,
    required int sessionSteps,
    required int territoriesCount,
    required int pointsEarned,
    required List<LatLng> routePoints,
  }) async {
    if (locationState is! LocationTracking || locationState.routePoints.isEmpty) {
      print('⚠️ No route data to save');
      return;
    }
    
    try {
      // Capture map screenshot before saving
      final mapSnapshot = await _captureMapScreenshot();
      
      final activity = Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        route: locationState.routePoints,
        distanceMeters: distance * 1000,
        duration: activeDuration,
        startTime: _trackingStartTime ?? DateTime.now(),
        endTime: DateTime.now(),
        caloriesBurned: (distance * 65).round(), // Rough estimate: 65 cal/km
        averageSpeed: avgSpeed,
        steps: sessionSteps,
        territoriesCaptured: territoriesCount,
        pointsEarned: pointsEarned,
        capturedAreaSqMeters: _estimatedAreaSqMeters > 0 ? _estimatedAreaSqMeters : null,
        capturedHexIds: _capturedHexIds.isNotEmpty ? _capturedHexIds.toList() : null,
        routeMapSnapshot: mapSnapshot,
      );
      
      final dataSource = ActivityLocalDataSourceImpl();
      await dataSource.saveActivity(activity);
      
      print('✅ Activity saved to history!');
    } catch (e) {
      print('❌ Error saving activity: $e');
    }
  }

  Widget _buildPipMode(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locationState) {
        CameraPosition cameraPosition = const CameraPosition(
          target: LatLng(37.7749, -122.4194),
          zoom: 15,
        );
        
        if (locationState is LocationIdle && locationState.lastPosition != null) {
          cameraPosition = CameraPosition(
            target: LatLng(
              locationState.lastPosition!.latitude,
              locationState.lastPosition!.longitude,
            ),
            zoom: 15,
          );
        } else if (locationState is LocationTracking) {
          cameraPosition = CameraPosition(
            target: LatLng(
              locationState.currentPosition.latitude,
              locationState.currentPosition.longitude,
            ),
            zoom: 16,
          );
        }
        
        return GoogleMap(
          initialCameraPosition: cameraPosition,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          polygons: _polygons,
          polylines: _polylines,
          mapType: _currentMapType,
          onMapCreated: (GoogleMapController controller) {
            // Don't store controller in PiP mode to avoid conflicts
          },
        );
      },
    );
  }
}
