import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/background_tracking_service.dart';
import '../../../../core/services/motion_detection_service.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/services/territory_api_service.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/services/route_api_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/user_profile_api_service.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../../core/services/avatar_preset_service.dart';
import '../../../../core/services/map_drop_service.dart';
import '../../../../core/services/poi_mission_service.dart';
import '../../../../core/services/rewards_shop_service.dart';
import '../../../../core/services/territory_prefetch_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/utils/picture_in_picture.dart';
import '../../../../core/algorithms/geospatial_algorithms.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/services/pip_service.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/widgets/rain_overlay.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../tracking/domain/entities/activity.dart';
import '../../../tracking/domain/entities/position.dart';
import '../../../tracking/data/datasources/activity_local_data_source.dart';
import '../../../tracking/data/datasources/pending_sync_data_source.dart';
import '../../../territory/data/datasources/territory_cache_data_source.dart';
import '../bloc/location_bloc.dart';
import '../../../territory/presentation/bloc/territory_bloc.dart';
import '../../../game/presentation/bloc/game_bloc.dart';
import '../../../territory/data/helpers/territory_grid_helper.dart';
import '../../../territory/domain/entities/territory.dart' as app;
import 'workout_summary_screen.dart';
import 'activity_history_sheet.dart';
import 'activity_detail_drawer.dart';
import 'sync_status_screen.dart';
import '../../../engagement/presentation/pages/poi_missions_sheet.dart';
import '../../../engagement/presentation/pages/rewards_shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapScreen extends StatefulWidget {
  final VoidCallback? onNavigateHome;

  const MapScreen({super.key, this.onNavigateHome});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum TrackingState { stopped, started, paused }

enum RouteTravelMode { walk, run, bike }

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, RouteAware, AutomaticKeepAliveClientMixin {
  final PipService _pipService = PipService();
  final ActivityLocalDataSource _activityLocalDataSource =
      ActivityLocalDataSourceImpl();
  late final OfflineSyncService _offlineSyncService;
  late final PendingSyncDataSource _pendingSyncDataSource;
  late final SharedPreferences _prefs;
  late final TerritoryCacheDataSource _territoryCacheDataSource;
  late final WebSocketService _webSocketService;
  late final MapDropService _mapDropService;
  late final PoiMissionService _poiMissionService;
  late final RewardsShopService _rewardsShopService;
  late final UserProfileApiService _userProfileApiService;
  late final AuthApiService _authApiService;
  late final http.Client _httpClient;
  late final TerritoryPrefetchService _territoryPrefetchService;
  final Map<String, Marker> _userMarkersById = {};
  static const String _offlineSnapshotKey = 'offline_map_snapshot';
  String? _offlineSnapshotBase64;
  bool _showOfflineSnapshot = false;
  final Map<String, BitmapDescriptor> _userAvatarIconCache = {};
  final Map<String, String> _userAvatarUrlCache = {};
  final Map<String, Map<String, dynamic>> _userProfileCache = {};
  final Map<String, DateTime> _userLastSeen = {};
  final Set<String> _profileFetchInFlight = {};
  Marker? _currentUserMarker;
  Timer? _locationBroadcastTimer;
  Timer? _liveUserCleanupTimer;
  String? _currentUserId;
  final Set<Polygon> _polygons = {};
  final Set<Polyline> _polylines = {};
  final Set<Marker> _territoryMarkers = {};
  Set<Marker> _dropMarkers = {};
  Set<Circle> _dropCircles = {};
  BitmapDescriptor? _dropMarkerIcon;
  bool _isDropIconLoading = false;
  Set<Marker> _poiMarkers = {};
  Set<Circle> _poiCircles = {};
  PoiMission? _activePoiMission;
  MapDropBoost? _activeDropBoost;
  DateTime? _lastEngagementUpdateAt;
  Timer? _boostTicker;
  Map<String, dynamic>? _weatherData;
  bool _isRaining = false;
  Timer? _weatherTimer;
  bool _locationServiceEnabled = true;
  geo.LocationPermission _locationPermissionStatus =
      geo.LocationPermission.denied;
  bool _preciseLocationGranted = true;
  bool _isCheckingLocationGate = false;
  bool _isMapReady = false;
  bool _dropsLoading = false;
  bool _hasLoadedDrops = false;
  Timer? _mapStartupTimer;
  bool _mapDataStarted = false;
  Color _markerRingColor = Colors.white;
  final Map<String, Map<String, dynamic>> _activityData =
      {}; // Store activity data by polylineId
  Timer? _territoryFetchDebounce;
  LatLng? _lastTerritoryFetchCenter;
  int _territoryFetchToken = 0;
  final Map<String, DateTime> _territoryFetchTimestamps = {};
  bool _allTerritoriesLoaded = false;
  bool _allTerritoriesLoading = false;
  static const int _territoryAllPageSize = 2000;
  static const List<double> _territoryFetchRadiiKm = [
    0.5,
    1.0,
    2.0,
    5.0,
    10.0,
  ];
  static const String _weatherApiKey = '5031f2deb028a21f969207e55fa35755';
  static const double _territoryFillOpacity = 0.03;
  static const double _capturedAreaFillOpacity = 0.02;
  static const double _territoryRefetchDistanceMeters = 250.0;
  static const Duration _territoryFetchTtl = Duration(minutes: 3);
  Timer? _territoryRefreshTimer;
  final Set<Circle> _heatmapCircles = {};
  bool _showHeatmap = false;
  List<Map<String, dynamic>> _activityHistory = [];
  late AnimationController _animController;
  late AnimationController _buttonAnimController;
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _is3DMode = true;
  double _currentSpeed = 0.0; // km/h
  DateTime? _lastSpeedUpdate;
  double _routeQualityScore = 0.0;
  String _routeQualityLabel = 'GPS';
  DateTime? _lastQualityUpdate;
  final double _splitDistanceMeters = 1000.0;
  int _splitIndex = 0;
  double _nextSplitAtMeters = 1000.0;
  DateTime? _lastSplitTime;
  String? _lastSplitPace;
  Duration? _lastSplitDuration;
  final Set<String> _capturedHexIds = {};
  List<LatLng> _territoryRoutePoints =
      []; // Actual route points for territory shape
  Map<String, Map<String, dynamic>> _territoryData =
      {}; // Store territory info by hexId
  double _lastDistanceUpdate = 0.0;
  double _lastNotificationDistance =
      0.0; // Track distance for notification updates
  int _lastTerritoryCount = 0;
  DateTime? _trackingStartTime;
  Circle? _startPointCircle; // Visual marker for start point
  double _distanceToStart = double.infinity; // Distance to starting point
  DateTime? _lastNotificationUpdate; // Throttle notification updates
  TrackingState _trackingState = TrackingState.stopped;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  int _loopStartIndex = 0;
  double _loopStartDistanceMeters = 0.0;
  bool _loopCaptureInFlight = false;
  DateTime? _lastLoopCaptureAt;
  final Set<String> _reportedHexIds = {};
  LatLng? _smoothedCameraTarget;
  double? _smoothedCameraBearing;
  DateTime? _lastCameraUpdate;
  DateTime? _lastRouteRenderAt;
  static const Duration _cameraUpdateThrottle =
      Duration(milliseconds: 260);
  static const Duration _routeRenderThrottle =
      Duration(milliseconds: 240);
  static const Duration _widgetUpdateThrottle =
      Duration(seconds: 12);
  DateTime? _lastWidgetUpdateAt;

  // Loop closure feedback
  bool _hasGivenCloseLoopFeedback = false;
  double _estimatedAreaSqMeters = 0.0;
  int _lastLoadedTerritoryCount = 0; // Track last loaded count to prevent spam
  int _currentSessionTerritories =
      0; // Track territories captured in current session
  int _localStreakDays = 0;
  int _bestStreakDays = 0;

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
  bool _isEndingSession = false;
  Timer? _endTimer;
  Timer? _syncStatusTimer;
  int _pendingSyncCount = 0;
  bool _isSyncing = false;
  bool _followUser = true;
  final Set<int> _activePointers = <int>{};

  // Long press to end
  bool _isHoldingEnd = false;

  // Simulation mode toggle
  bool _useSimulation = false;
  bool _batterySaverEnabled = false;
  bool _showAdvancedControls = false;
  bool _isPlanningRoute = false;
  List<LatLng> _plannedRoutePoints = [];
  List<LatLng> _plannedRoutePreviewPoints = [];
  List<SavedRoute> _savedRoutes = [];
  List<SavedRoute> _popularRoutes = [];
  bool _isLoadingSavedRoutes = false;
  bool _isLoadingPopularRoutes = false;
  bool _hasCachedSavedRoutes = false;
  bool _hasCachedPopularRoutes = false;
  bool _isRefreshingSavedRoutes = false;
  bool _isRefreshingPopularRoutes = false;
  static const String _savedRoutesCacheKey = 'routes_saved_cache_v1';
  static const String _popularRoutesCacheKeyPrefix = 'routes_popular_cache_v1';
  static const String _popularRoutesCacheKeyLast =
      'routes_popular_cache_last_v1';
  final Uuid _uuid = Uuid();
  String? _currentLoopId;
  SavedRoute? _selectedRoute;
  bool _isRealtimeRouteEnabled = true;
  RouteTravelMode _routeTravelMode = RouteTravelMode.walk;
  double _routeTotalMeters = 0.0;
  double _routeRemainingMeters = 0.0;
  double _routeDeviationMeters = 0.0;
  Duration? _routeEta;
  DateTime? _lastRoutePreviewUpdate;
  static const Duration _routePreviewThrottle = Duration(milliseconds: 700);
  static const double _offRouteThresholdMeters = 30.0;
  LatLng? _lastKnownLocation;
  double? _goalDistanceKm;
  double? _goalAreaSqMeters;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  static const Duration _holdDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _offlineSyncService = di.getIt<OfflineSyncService>();
    _pendingSyncDataSource = di.getIt<PendingSyncDataSource>();
    _prefs = di.getIt<SharedPreferences>();
    _territoryCacheDataSource = TerritoryCacheDataSource(_prefs);
    _webSocketService = di.getIt<WebSocketService>();
    _mapDropService = di.getIt<MapDropService>();
    _poiMissionService = di.getIt<PoiMissionService>();
    _rewardsShopService = di.getIt<RewardsShopService>();
    _userProfileApiService = di.getIt<UserProfileApiService>();
    _authApiService = di.getIt<AuthApiService>();
    _httpClient = di.getIt<http.Client>();
    _territoryPrefetchService = di.getIt<TerritoryPrefetchService>();
    _offlineSnapshotBase64 = _prefs.getString(_offlineSnapshotKey);
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
    _mapStartupTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _startMapDataLoadOnce();
    });

    // Get initial location
    // IMPORTANT: Stop any previous tracking session first
    context.read<LocationBloc>().add(StopLocationTracking());
    context.read<LocationBloc>().add(GetInitialLocation());
    context.read<TerritoryBloc>().add(LoadTerritories());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkPreciseLocationAccess(requestPermission: true));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _pipService.disablePip();
  }

  @override
  void didPopNext() {
    _pipService.enablePipForScreen('map');
    unawaited(_checkPreciseLocationAccess());
  }

  void _startMapDataLoadOnce() {
    if (_mapDataStarted) return;
    _mapDataStarted = true;
    _mapStartupTimer?.cancel();
    if (!_hasLoadedDrops) {
      _dropsLoading = true;
      if (mounted) {
        setState(() {});
      }
    }

    // Load captured areas from activity history to show on map
    _loadSavedCapturedAreas();

    // Load cached nearby territories first (fast), then full sets.
    _loadCachedNearbyTerritories();
    _loadTerritoriesFromBackend();
    _loadBossTerritoriesFromBackend();

    unawaited(_initEngagementSystems());

    _fetchWeatherForMap();
    _weatherTimer ??= Timer.periodic(
      const Duration(minutes: 15),
      (_) => _fetchWeatherForMap(),
    );

    // Prefetch nearby territories once map is live.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_territoryPrefetchService.prefetchAroundUser());
    });

    // Kick off any pending offline sync in background
    _refreshSyncStatus();
    _triggerBackgroundSync();
    _syncStatusTimer ??= Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshSyncStatus(),
    );

    _authApiService.getUserId().then((id) => _currentUserId = id);
    _webSocketService.onUserLocation(_handleUserLocation);
    _webSocketService.onTerritoryCaptured(_handleTerritoryCaptured);
    _webSocketService.onTerritorySnapshot(_handleTerritorySnapshot);
    _webSocketService.onDropBoostUpdate(_handleBoostUpdate);
    _ensureWebSocketConnected();
    _locationBroadcastTimer ??= Timer.periodic(
      const Duration(seconds: 6),
      (_) => _emitMyLocationUpdate(),
    );
    _liveUserCleanupTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pruneStaleUsers(),
    );

    _territoryRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) {
        if (!mounted) return;
        if (!_webSocketService.isConnected) {
          _ensureWebSocketConnected();
          _refreshRecentTerritories();
        }
      },
    );
  }

  Future<void> _checkPreciseLocationAccess({bool requestPermission = false}) async {
    if (_isCheckingLocationGate) return;
    if (mounted) {
      setState(() => _isCheckingLocationGate = true);
    } else {
      _isCheckingLocationGate = true;
    }

    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      _locationServiceEnabled = serviceEnabled;
      if (!serviceEnabled) {
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied && requestPermission) {
        permission = await geo.Geolocator.requestPermission();
      }
      _locationPermissionStatus = permission;

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _preciseLocationGranted = false;
        return;
      }

      _preciseLocationGranted = await _isPreciseLocationGranted();
    } catch (e) {
      print('Failed to check location accuracy: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingLocationGate = false);
      } else {
        _isCheckingLocationGate = false;
      }
    }
  }

  Future<bool> _isPreciseLocationGranted() async {
    try {
      final accuracyStatus = await geo.Geolocator.getLocationAccuracy();
      if (accuracyStatus == geo.LocationAccuracyStatus.precise) {
        return true;
      }
      if (accuracyStatus == geo.LocationAccuracyStatus.reduced) {
        return false;
      }
    } catch (_) {
      // Some platforms do not report accuracy status.
    }

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      return position.accuracy <= 65;
    } catch (_) {
      return true;
    }
  }

  bool get _showLocationGate {
    if (!_locationServiceEnabled) return true;
    if (_locationPermissionStatus == geo.LocationPermission.denied ||
        _locationPermissionStatus == geo.LocationPermission.deniedForever) {
      return true;
    }
    return !_preciseLocationGranted;
  }

  String _locationGateTitle() {
    if (!_locationServiceEnabled) {
      return 'Enable location services';
    }
    if (_locationPermissionStatus == geo.LocationPermission.denied) {
      return 'Location permission needed';
    }
    if (_locationPermissionStatus == geo.LocationPermission.deniedForever) {
      return 'Location permission disabled';
    }
    return 'Precise location required';
  }

  String _locationGateMessage() {
    if (!_locationServiceEnabled) {
      return 'Turn on location services to use the map.';
    }
    if (_locationPermissionStatus == geo.LocationPermission.denied) {
      return 'Allow location access to show your position and capture territory.';
    }
    if (_locationPermissionStatus == geo.LocationPermission.deniedForever) {
      return 'Enable location permission in Settings to use the map.';
    }
    return 'Enable precise location. Approximate location will not work for the map.';
  }

  Future<void> _handleLocationGatePrimaryAction() async {
    if (!_locationServiceEnabled) {
      await geo.Geolocator.openLocationSettings();
      return;
    }
    if (_locationPermissionStatus == geo.LocationPermission.denied) {
      await _checkPreciseLocationAccess(requestPermission: true);
      return;
    }
    await geo.Geolocator.openAppSettings();
  }

  String _locationGatePrimaryLabel() {
    if (!_locationServiceEnabled) {
      return 'Open location settings';
    }
    if (_locationPermissionStatus == geo.LocationPermission.denied) {
      return 'Allow location';
    }
    return 'Open app settings';
  }

  Future<void> _ensureWebSocketConnected() async {
    if (_webSocketService.isConnected) return;
    try {
      final userId = await _authApiService.getUserId();
      final token = await _authApiService.getToken();
      if (userId != null && token != null && token.isNotEmpty) {
        await _webSocketService.connect(userId, token: token);
      }
    } catch (e) {
      print('Failed to ensure WebSocket connection: $e');
    }
  }

  void _pruneTerritoryFetchKeys() {
    final cutoff = DateTime.now().subtract(_territoryFetchTtl);
    _territoryFetchTimestamps.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  Future<void> _refreshRecentTerritories() async {
    try {
      final territoryApiService = di.getIt<TerritoryApiService>();
      final authService = di.getIt<AuthApiService>();
      final currentUserId = await authService.getUserId() ?? '';
      final territories = await territoryApiService.getAllTerritories(
        limit: 250,
        offset: 0,
      );
      if (!mounted) return;
      _renderTerritories(territories, currentUserId);
    } catch (e) {
      print('Failed to refresh recent territories: $e');
    }
  }

  // Load every territory (public data) so all users see the full map.
  Future<void> _loadTerritoriesFromBackend({LatLng? center}) async {
    if (_allTerritoriesLoaded || _allTerritoriesLoading) return;
    _allTerritoriesLoading = true;

    final territoryApiService = di.getIt<TerritoryApiService>();
    final authService = di.getIt<AuthApiService>();
    final currentUserId = await authService.getUserId() ?? '';

    try {
      int offset = 0;
      while (mounted) {
        final territories = await territoryApiService.getAllTerritories(
          limit: _territoryAllPageSize,
          offset: offset,
        );
        if (!mounted) return;
        if (territories.isEmpty) break;
        _renderTerritories(territories, currentUserId);
        offset += territories.length;
        if (territories.length < _territoryAllPageSize) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      _allTerritoriesLoaded = true;
    } catch (e) {
      print('Failed to load all territories: $e');
    } finally {
      _allTerritoriesLoading = false;
    }
  }

  Future<void> _loadCachedNearbyTerritories() async {
    try {
      final cached = await _territoryCacheDataSource.getNearbyTerritories();
      if (cached.isEmpty || !mounted) return;
      final currentUserId = _currentUserIdFromAuth() ?? _currentUserId ?? '';
      _renderTerritories(cached, currentUserId);
    } catch (e) {
      print('Failed to load cached nearby territories: $e');
    }
  }

  String _territoryFetchKey(LatLng center, double radiusKm) {
    final lat = center.latitude.toStringAsFixed(3);
    final lng = center.longitude.toStringAsFixed(3);
    final r = radiusKm.toStringAsFixed(2);
    return 'lat:$lat,lng:$lng,r:$r';
  }

  void _scheduleTerritoryFetch(LatLng center, {bool force = false}) {
    if (_allTerritoriesLoaded || _allTerritoriesLoading) {
      return;
    }
    _pruneTerritoryFetchKeys();
    if (!force && _lastTerritoryFetchCenter != null) {
      final moved = GeodesicCalculator.fastDistance(
        _lastTerritoryFetchCenter!,
        center,
      );
      if (moved < _territoryRefetchDistanceMeters) {
        return;
      }
    }

    _lastTerritoryFetchCenter = center;
    _territoryFetchToken += 1;
    final token = _territoryFetchToken;

    _territoryFetchDebounce?.cancel();
    _territoryFetchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchTerritoriesProgressively(center, token);
    });
  }

  Future<void> _fetchTerritoriesProgressively(
    LatLng center,
    int token,
  ) async {
    final territoryApiService = di.getIt<TerritoryApiService>();
    final authService = di.getIt<AuthApiService>();
    final currentUserId = await authService.getUserId() ?? '';

    for (final radiusKm in _territoryFetchRadiiKm) {
      if (!mounted || token != _territoryFetchToken) return;
      final key = _territoryFetchKey(center, radiusKm);
      final lastFetchAt = _territoryFetchTimestamps[key];
      if (lastFetchAt != null &&
          DateTime.now().difference(lastFetchAt) < _territoryFetchTtl) {
        continue;
      }
      _territoryFetchTimestamps[key] = DateTime.now();
      try {
        final territories = await territoryApiService.getNearbyTerritories(
          lat: center.latitude,
          lng: center.longitude,
          radius: radiusKm,
        );
        if (!mounted || token != _territoryFetchToken) return;
        _renderTerritories(territories, currentUserId);
      } catch (e) {
        print('Failed to load nearby territories (r=$radiusKm): $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _renderTerritories(
    List<Map<String, dynamic>> territories,
    String currentUserId,
  ) {
    if (!mounted) return;
    print('Current user: $currentUserId');

    final Map<String, Map<String, dynamic>> uniqueTerritories = {};
    for (final territory in territories) {
      final hexId = territory['hexId'];
      if (!uniqueTerritories.containsKey(hexId)) {
        uniqueTerritories[hexId] = territory;
      }
    }

    final displayTerritories = uniqueTerritories.values.toList();
    print(
      'Filtered ${territories.length} territories down to ${displayTerritories.length} unique hexes',
    );

    setState(() {
      for (final territory in displayTerritories) {
        final hexId = territory['hexId']?.toString() ?? '';
        if (hexId.isEmpty) {
          continue;
        }
        final lat = territory['latitude'] is String
            ? double.parse(territory['latitude'])
            : (territory['latitude'] as num).toDouble();
        final lng = territory['longitude'] is String
            ? double.parse(territory['longitude'])
            : (territory['longitude'] as num).toDouble();

        final ownerId = territory['ownerId'];
        final bool isOwnTerritory = ownerId == currentUserId;
        final territoryColor =
            isOwnTerritory ? const Color(0xFF4CAF50) : const Color(0xFFFF5722);

        final routePoints = territory['routePoints'] as List?;
        List<LatLng>? polygonPoints;

        if (routePoints != null && routePoints.isNotEmpty) {
          final parsedPoints = routePoints
              .map(_parseRoutePoint)
              .whereType<LatLng>()
              .toList();
          if (parsedPoints.length >= 3) {
            polygonPoints = parsedPoints;
          }
        }

        if (polygonPoints == null) {
          polygonPoints = _generateCirclePoints(LatLng(lat, lng), 25);
        }

        final polygonId = 'territory_$hexId';
        _polygons.removeWhere(
          (polygon) => polygon.polygonId.value == polygonId,
        );
        _polygons.add(
          Polygon(
            polygonId: PolygonId(polygonId),
            points: polygonPoints,
            fillColor: territoryColor.withOpacity(_territoryFillOpacity),
            strokeColor: territoryColor.withOpacity(0.5),
            strokeWidth: polygonPoints.length >= 3 ? 2 : 1,
          ),
        );

        _territoryData[hexId] = {
          'polygonPoints': polygonPoints,
          'territoryId': territory['id']?.toString(),
          'ownerId': ownerId,
          'ownerName': territory['owner']?['name'] ?? 'Unknown',
          'captureCount': territory['captureCount'] ?? 1,
          'isOwn': isOwnTerritory,
          'points': territory['points'],
          'capturedAt': territory['capturedAt'] != null
              ? DateTime.parse(territory['capturedAt'])
              : null,
          'lastBattleAt': territory['lastBattleAt'] != null
              ? DateTime.parse(territory['lastBattleAt'])
              : null,
          'areaSqMeters': _calculatePolygonArea(polygonPoints),
        };
      }
    });

    if (displayTerritories.isNotEmpty) {
      print('Displayed ${displayTerritories.length} unique territories');
      print('Total polygons on map: ${_polygons.length}');
      print('Total markers on map: ${_territoryMarkers.length}');
    }
  }

  // Handle map tap to check if user tapped on a territory
  void _handleMapTap(LatLng tapPosition) {
    for (final entry in _territoryData.entries) {
      final hexId = entry.key;
      final data = entry.value;
      final polygonPoints = data['polygonPoints'] as List<LatLng>;

      // Check if tap is inside this polygon
      if (_isPointInPolygon(tapPosition, polygonPoints)) {
        final ownerId = data['ownerId']?.toString();
        String? avatarSource;
        if (data['isOwn'] == true) {
          avatarSource = _currentUserAvatarSource();
        }
        if ((avatarSource == null || avatarSource.isEmpty) &&
            ownerId != null &&
            ownerId.isNotEmpty) {
          avatarSource = _extractAvatarFromMap(_userProfileCache[ownerId]);
        }
        _showTerritoryInfo(
          ownerName: data['ownerName'],
          captureCount: data['captureCount'],
          isOwn: data['isOwn'],
          points: data['points'],
          capturedAt: data['capturedAt'],
          lastBattleAt: data['lastBattleAt'],
          areaSqMeters: data['areaSqMeters'],
          isBoss: data['isBoss'] == true,
          bossRewardPoints: data['bossRewardPoints'],
          avatarSource: avatarSource,
          territoryId: data['territoryId']?.toString(),
        );
        break;
      }
    }
  }

  // Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final vertex1 = polygon[i];
      final vertex2 = polygon[(i + 1) % polygon.length];

      if (_rayCastIntersect(point, vertex1, vertex2)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  bool _rayCastIntersect(LatLng point, LatLng vertex1, LatLng vertex2) {
    final px = point.longitude;
    final py = point.latitude;
    final v1x = vertex1.longitude;
    final v1y = vertex1.latitude;
    final v2x = vertex2.longitude;
    final v2y = vertex2.latitude;

    if ((v1y > py) != (v2y > py)) {
      final intersectX = (v2x - v1x) * (py - v1y) / (v2y - v1y) + v1x;
      if (px < intersectX) {
        return true;
      }
    }
    return false;
  }

  // Show territory information dialog
  void _showTerritoryInfo({
    required String ownerName,
    required int captureCount,
    required bool isOwn,
    int? points,
    DateTime? capturedAt,
    DateTime? lastBattleAt,
    double? areaSqMeters,
    bool isBoss = false,
    int? bossRewardPoints,
    String? avatarSource,
    String? territoryId,
  }) {
    final accent = isBoss
        ? const Color(0xFFF5B700)
        : (isOwn ? const Color(0xFF2ECC71) : const Color(0xFFF39C12));
    final headline = isOwn ? 'Your Territory' : 'Territory';
    final subtitle = isOwn ? 'Owned by you' : 'Owned by $ownerName';
    final territoryIdText = territoryId?.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (context) {
        final media = MediaQuery.of(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + media.viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned(
                      right: -70,
                      top: -90,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accent.withOpacity(0.18),
                              accent.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTerritoryHeader(
                                title: headline,
                                subtitle: subtitle,
                                accent: accent,
                                isBoss: isBoss,
                                avatarSource: avatarSource,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatusChip(
                                    label: isOwn ? 'Owned' : 'Rival',
                                    icon: isOwn ? Icons.check : Icons.flag,
                                    color: accent,
                                  ),
                                  if (isBoss)
                                    _buildStatusChip(
                                      label: 'Boss Zone',
                                      icon: Icons.emoji_events,
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildTerritoryStatChip(
                                    icon: Icons.flag_outlined,
                                    label: 'Captures',
                                    value: '$captureCount',
                                    color: const Color(0xFF2563EB),
                                  ),
                                  if (points != null)
                                    _buildTerritoryStatChip(
                                      icon: Icons.stars,
                                      label: 'Points',
                                      value: '$points',
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  if (areaSqMeters != null)
                                    _buildTerritoryStatChip(
                                      icon: Icons.area_chart,
                                      label: 'Area',
                                      value: _formatAreaForCard(areaSqMeters),
                                      color: const Color(0xFF7C3AED),
                                    ),
                                ],
                              ),
                              if (isBoss) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFFF4CC),
                                        const Color(0xFFFFE08A),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events,
                                        color: Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          bossRewardPoints != null
                                              ? '$bossRewardPoints pts reward'
                                              : 'Weekly boss territory bonus',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (capturedAt != null || lastBattleAt != null)
                                const SizedBox(height: 16),
                              if (capturedAt != null)
                                _buildTerritoryInfoRow(
                                  icon: Icons.calendar_today,
                                  label: 'Captured',
                                  value: _formatDate(capturedAt),
                                ),
                              if (capturedAt != null && lastBattleAt != null)
                                const SizedBox(height: 10),
                              if (lastBattleAt != null)
                                _buildTerritoryInfoRow(
                                  icon: Icons.shield,
                                  label: 'Last battle',
                                  value: _formatDate(lastBattleAt),
                                ),
                              if (territoryIdText != null &&
                                  territoryIdText.isNotEmpty) ...[
                                if (capturedAt != null || lastBattleAt != null)
                                  const SizedBox(height: 10),
                                _buildTerritoryInfoRow(
                                  icon: Icons.tag,
                                  label: 'Territory ID',
                                  value: territoryIdText,
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                        foregroundColor:
                                            const Color(0xFF111827),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        textStyle: GoogleFonts.spaceGrotesk(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: const Text('Close'),
                                    ),
                                  ),
                                  if (!isOwn) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Start tracking to challenge this territory!',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.sports_martial_arts,
                                        ),
                                        label: const Text('Challenge'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          textStyle: GoogleFonts.spaceGrotesk(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTerritoryHeader({
    required String title,
    required String subtitle,
    required Color accent,
    required bool isBoss,
    String? avatarSource,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildOwnerAvatar(avatarSource, accent),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              if (isBoss)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Boss territory',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerAvatar(String? avatarSource, Color accent) {
    final resolvedUrl = AvatarPresetService.resolveAvatarImageUrl(avatarSource);
    final hasAvatar = resolvedUrl.isNotEmpty;
    final isAssetPath = resolvedUrl.startsWith('assets/');

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.95),
            accent.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: hasAvatar
            ? (isAssetPath
                ? Image.asset(resolvedUrl, fit: BoxFit.cover)
                : CachedNetworkImage(
                    imageUrl: resolvedUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFF3F4F6),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: Icon(
                        Icons.person,
                        color: accent,
                        size: 28,
                      ),
                    ),
                  ))
            : Container(
                color: const Color(0xFFF3F4F6),
                child: Icon(
                  Icons.person,
                  color: accent,
                  size: 28,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerritoryStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerritoryInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  String _formatAreaForCard(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} km?';
    }
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k m?';
    }
    return '${value.toStringAsFixed(0)} m?';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Helper to generate circle points for territory display
  List<LatLng> _generateCirclePoints(
    LatLng center,
    double radiusMeters, {
    int points = 32,
  }) {
    final circlePoints = <LatLng>[];
    const earthRadius = 6371000.0; // Earth's radius in meters

    for (int i = 0; i <= points; i++) {
      final angle = (i * 360 / points) * (3.14159265359 / 180);
      final dx = radiusMeters * cos(angle);
      final dy = radiusMeters * sin(angle);

      final deltaLat = dy / earthRadius;
      final deltaLng =
          dx / (earthRadius * cos(center.latitude * 3.14159265359 / 180));

      circlePoints.add(
        LatLng(
          center.latitude + (deltaLat * 180 / 3.14159265359),
          center.longitude + (deltaLng * 180 / 3.14159265359),
        ),
      );
    }

    return circlePoints;
  }

  Map<String, dynamic> _normalizeActivityData(Map<String, dynamic> activity) {
    if (activity['routePoints'] == null && activity['route'] != null) {
      return {...activity, 'routePoints': activity['route']};
    }
    return activity;
  }

  String? _extractAvatarSource(Map<String, dynamic> activityData) {
    final userData = activityData['user'];
    return _extractAvatarFromMap(userData) ?? _extractAvatarFromMap(activityData);
  }

  String? _extractAvatarFromMap(dynamic data) {
    if (data is! Map) return null;
    final avatarImage = data['avatarImageUrl']?.toString();
    if (avatarImage != null && avatarImage.isNotEmpty) return avatarImage;
    final avatarModel = data['avatarModelUrl']?.toString();
    if (avatarModel != null && avatarModel.isNotEmpty) return avatarModel;
    final avatarUrl = data['avatarUrl']?.toString();
    if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
    final profilePicture = data['profilePicture']?.toString();
    if (profilePicture != null && profilePicture.isNotEmpty) {
      return profilePicture;
    }
    return null;
  }

  String? _currentUserAvatarSource() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return null;
    return authState.user.avatarImageUrl ?? authState.user.avatarModelUrl;
  }

  String? _currentUserIdFromAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return null;
    return authState.user.id;
  }

  void _scheduleCapturedAreaAvatarUpdate({
    required String markerId,
    required LatLng position,
    required String avatarCacheKey,
    required String avatarSource,
    VoidCallback? onTap,
  }) {
    if (avatarSource.isEmpty) return;
    _updateCapturedAreaMarkerAvatar(
      markerId: markerId,
      position: position,
      avatarCacheKey: avatarCacheKey,
      avatarSource: avatarSource,
      onTap: onTap,
    );
  }

  Future<void> _updateCapturedAreaMarkerAvatar({
    required String markerId,
    required LatLng position,
    required String avatarCacheKey,
    required String avatarSource,
    VoidCallback? onTap,
  }) async {
    final icon = await _getAvatarMarkerIcon(avatarCacheKey, avatarSource);
    if (icon == null || !mounted) return;
    setState(() {
      _territoryMarkers.removeWhere(
        (marker) => marker.markerId.value == markerId,
      );
      _territoryMarkers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: onTap,
        ),
      );
    });
  }

  LatLng? _parseRoutePoint(dynamic point) {
    if (point is Map) {
      final latRaw =
          point['latitude'] ?? point['lat'] ?? point['Latitude'] ?? point['Lat'];
      final lngRaw = point['longitude'] ??
          point['lng'] ??
          point['lon'] ??
          point['Longitude'] ??
          point['Lng'];
      final lat = _toDoubleSafe(latRaw);
      final lng = _toDoubleSafe(lngRaw);
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }
    if (point is List && point.length >= 2) {
      final lat = _toDoubleSafe(point[0]);
      final lng = _toDoubleSafe(point[1]);
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }
    return null;
  }

  String _captureKeyForActivity(
    List<LatLng> routePoints,
    dynamic capturedHexIds,
  ) {
    if (capturedHexIds is List && capturedHexIds.isNotEmpty) {
      final ids = capturedHexIds
          .map((id) => id?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) {
        ids.sort();
        return 'hex:${ids.join('|')}';
      }
    }

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;
    for (final point in routePoints.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final centerLat = ((minLat + maxLat) / 2).toStringAsFixed(4);
    final centerLng = ((minLng + maxLng) / 2).toStringAsFixed(4);
    return 'route:$centerLat,$centerLng,${routePoints.length}';
  }

  double? _toDoubleSafe(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int _toIntSafe(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  DateTime? _parseDateTimeSafe(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  // Load all previously captured areas from activity history (backend-first)
  Future<void> _loadSavedCapturedAreas() async {
    try {
      print('📂 Loading saved captured areas from backend...');
      final trackingApiService = di.getIt<TrackingApiService>();
      List<Map<String, dynamic>> activitiesData = [];
      try {
        activitiesData = await trackingApiService.getUserActivities(limit: 50);
        for (final data in activitiesData) {
          try {
            final activity = Activity.fromJson(data);
            await _activityLocalDataSource.saveActivity(activity);
          } catch (e) {
            print('[warn] Failed to cache activity locally: $e');
          }
        }
      } catch (e) {
        print('[warn] Could not load from backend: $e');
        final localActivities =
            await _activityLocalDataSource.getAllActivities();
        activitiesData =
            localActivities.map((activity) => activity.toJson()).toList();
        if (activitiesData.isNotEmpty) {
          print('[cache] Using cached activities (${activitiesData.length})');
        }
      }

      print('[info] Loaded ${activitiesData.length} activities');

      _activityHistory =
          activitiesData.map((a) => _normalizeActivityData(a)).toList();
      _updateLocalStreaks();
      if (_showHeatmap) {
        _buildHeatmapCircles();
      }

      int loadedCount = 0;
      final pendingAvatarMarkers = <Map<String, dynamic>>[];
      final seenCaptureKeys = <String>{};
      setState(() {
        // Remove only activity polygons and polylines, keep territory polygons
        _polygons.removeWhere(
          (polygon) => polygon.polygonId.value.startsWith('saved_area_'),
        );
        _polylines.clear();

        // Clear only activity-related markers (not territory markers)
        _territoryMarkers.removeWhere(
          (marker) => marker.markerId.value.startsWith('label_'),
        );

        // Clear only activity data, keep territory data
        _activityData.removeWhere(
          (key, value) =>
              key.startsWith('saved_area_') || key.startsWith('saved_route_'),
        );

        // Load each activity's captured area (only those with territories captured)
        for (int i = 0; i < _activityHistory.length; i++) {
          final activityData = _activityHistory[i];
          print('📦 Activity ${i + 1}: ${activityData.keys.toList()}');
          if (activityData.containsKey('user')) {
            final userData = activityData['user'];
            print('👤 User data found: $userData');
            print(
              '   - Name: ${userData is Map ? userData['name'] : 'not a map'}',
            );
            print(
              '   - Email: ${userData is Map ? userData['email'] : 'not a map'}',
            );
          } else {
            print('❌ No user data in activity');
          }
          final territoriesCapturedRaw = activityData['territoriesCaptured'];
          final territoriesCaptured = territoriesCapturedRaw is num
              ? territoriesCapturedRaw
              : double.tryParse(territoriesCapturedRaw?.toString() ?? '0') ?? 0;
          final capturedAreaSqMetersRaw = activityData['capturedAreaSqMeters'];
          final capturedAreaSqMeters = capturedAreaSqMetersRaw is num
              ? capturedAreaSqMetersRaw
              : double.tryParse(capturedAreaSqMetersRaw?.toString() ?? '');
          final capturedHexIds = activityData['capturedHexIds'];
          final hasCapturedArea = territoriesCaptured > 0 ||
              (capturedAreaSqMeters != null && capturedAreaSqMeters > 0) ||
              (capturedHexIds is List && capturedHexIds.isNotEmpty);

          final routeData = activityData['routePoints'] as List<dynamic>?;
          if (routeData == null || routeData.isEmpty) {
            continue;
          }

          // Convert route points to LatLng safely
          final routePoints = routeData
              .map(_parseRoutePoint)
              .whereType<LatLng>()
              .toList();
          if (routePoints.length < 2) {
            print('[warn] Skipping activity ${activityData['id']} - not enough valid points');
            continue;
          }

          final captureKey = hasCapturedArea
              ? _captureKeyForActivity(routePoints, capturedHexIds)
              : null;
          final isDuplicateCapture =
              captureKey != null && seenCaptureKeys.contains(captureKey);
          if (captureKey != null && !isDuplicateCapture) {
            seenCaptureKeys.add(captureKey);
          }

          if (hasCapturedArea &&
              routePoints.length >= 3 &&
              !isDuplicateCapture) {
            // Add filled area polygon matching the walked path
            final polygonId = 'saved_area_${activityData['id']}';
            _activityData[polygonId] = activityData;
            _polygons.add(
              Polygon(
                polygonId: PolygonId(polygonId),
                points: routePoints,
                fillColor:
                    const Color(0xFF4CAF50).withOpacity(_capturedAreaFillOpacity),
                strokeColor: const Color(0xFF2E7D32).withOpacity(0.7),
                strokeWidth: 2,
                consumeTapEvents: true,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) =>
                        ActivityDetailDrawer(activity: activityData),
                  );
                },
              ),
            );
          }

          // Add tappable polyline for route (always)
          final polylineId = 'saved_route_${activityData['id']}';
          _activityData[polylineId] = activityData;
          _polylines.add(
            Polyline(
              polylineId: PolylineId(polylineId),
              points: routePoints,
              color: hasCapturedArea
                  ? Color(0xFF2196F3) // Brighter blue
                  : Colors.blueGrey.withOpacity(0.7),
              width: hasCapturedArea ? 6 : 4,
              consumeTapEvents: true,
              onTap: () {
                print('Polyline tapped: $polylineId');
                _handlePolylineTap(PolylineId(polylineId));
              },
            ),
          );

          // Add marker at center with username (captured areas only)
          if (hasCapturedArea && routePoints.isNotEmpty && !isDuplicateCapture) {
            double sumLat = 0, sumLng = 0;
            for (final point in routePoints) {
              sumLat += point.latitude;
              sumLng += point.longitude;
            }
            final center = LatLng(
              sumLat / routePoints.length,
              sumLng / routePoints.length,
            );
            final markerId = 'label_${activityData['id']}';
            final userData = activityData['user'];
            final ownerName = userData is Map
                ? (userData['name']?.toString() ?? 'You')
                : 'You';
            final ownerId = userData is Map
                ? (userData['id']?.toString() ??
                    userData['userId']?.toString())
                : null;
            final isOwn =
                ownerId == null || ownerId == _currentUserIdFromAuth();
            final captureCountRaw = _toIntSafe(
              activityData['territoriesCaptured'],
            );
            final captureCount =
                captureCountRaw > 0 ? captureCountRaw : 1;
            final points = activityData['pointsEarned'] != null
                ? _toIntSafe(activityData['pointsEarned'])
                : null;
            final areaSqMeters =
                _toDoubleSafe(activityData['capturedAreaSqMeters']);
            final capturedAt = _parseDateTimeSafe(
              activityData['startTime'] ??
                  activityData['capturedAt'] ??
                  activityData['createdAt'],
            );

            _territoryMarkers.add(
              Marker(
                markerId: MarkerId(markerId),
                position: center,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
                onTap: () {
                  _showTerritoryInfo(
                    ownerName: ownerName,
                    captureCount: captureCount,
                    isOwn: isOwn,
                    points: points,
                    capturedAt: capturedAt,
                    areaSqMeters: areaSqMeters,
                    avatarSource:
                        _extractAvatarSource(activityData) ??
                        _currentUserAvatarSource(),
                  );
                },
              ),
            );

            final avatarSource =
                _extractAvatarSource(activityData) ??
                _currentUserAvatarSource();
            final avatarCacheKey = userData is Map
                ? (userData['id']?.toString() ??
                    userData['userId']?.toString())
                : null;
            final cacheKey =
                avatarCacheKey ?? _currentUserIdFromAuth() ?? markerId;
            if (avatarSource != null && avatarSource.isNotEmpty) {
              pendingAvatarMarkers.add({
                'markerId': markerId,
                'position': center,
                'avatarSource': avatarSource,
                'cacheKey': cacheKey,
                'onTap': () {
                  _showTerritoryInfo(
                    ownerName: ownerName,
                    captureCount: captureCount,
                    isOwn: isOwn,
                    points: points,
                    capturedAt: capturedAt,
                    areaSqMeters: areaSqMeters,
                    avatarSource: avatarSource,
                  );
                },
              });
            }
          }
          loadedCount++;
        }
      });

      for (final pending in pendingAvatarMarkers) {
        _scheduleCapturedAreaAvatarUpdate(
          markerId: pending['markerId'] as String,
          position: pending['position'] as LatLng,
          avatarCacheKey: pending['cacheKey'] as String,
          avatarSource: pending['avatarSource'] as String,
          onTap: pending['onTap'] as VoidCallback?,
        );
      }

      print('✅ Loaded $loadedCount captured territory areas from backend');
    } catch (e) {
      print('❌ Error loading saved areas from backend: $e');
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

  Future<void> _initEngagementSystems() async {
    await _mapDropService.initialize();
    await _poiMissionService.initialize();
    await _rewardsShopService.initialize();
    _refreshMarkerCosmetics();
    await _ensureDropMarkerIcon();
    _refreshDropMarkers();
    _refreshPoiMarkers();
  }

  Future<void> _fetchWeatherForMap() async {
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));

      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_weatherApiKey&units=metric';
      final response =
          await _httpClient.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;
      final data = json.decode(response.body);
      final raining = _isRainingFromWeather(data);
      if (!mounted) return;
      setState(() {
        _weatherData = data;
        _isRaining = raining;
      });
    } catch (e) {
      print('Map weather fetch failed: $e');
    }
  }

  bool _isRainingFromWeather(Map<String, dynamic> data) {
    try {
      final main =
          data['weather'][0]['main'].toString().toLowerCase();
      return main.contains('rain') ||
          main.contains('drizzle') ||
          main.contains('thunder');
    } catch (_) {
      return false;
    }
  }

  double _rainIntensityFromWeather() {
    if (_weatherData == null) return 0.5;
    final main =
        _weatherData!['weather'][0]['main'].toString().toLowerCase();
    final desc =
        _weatherData!['weather'][0]['description'].toString().toLowerCase();
    if (main.contains('thunder') || desc.contains('heavy')) {
      return 0.8;
    }
    if (main.contains('drizzle') || desc.contains('light')) {
      return 0.35;
    }
    return 0.6;
  }

  Future<void> _handleEngagementUpdate(LatLng position) async {
    final now = DateTime.now();
    if (_lastEngagementUpdateAt != null &&
        now.difference(_lastEngagementUpdateAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastEngagementUpdateAt = now;

    if (!_hasLoadedDrops) {
      _dropsLoading = true;
      if (mounted) {
        setState(() {});
      }
    }

    bool dropsSynced = false;
    try {
      final pickup = await _mapDropService.syncDrops(position);
      dropsSynced = true;
      if (pickup.pickedDrops.isNotEmpty) {
        _showDropPickupSnack();
      }
      _activeDropBoost = _mapDropService.activeBoost;
      _refreshDropMarkers();
      _syncBoostTicker();

      final mission = await _poiMissionService.ensureMission(position);
      final missionChanged = _activePoiMission?.id != mission.id ||
          _activePoiMission?.visited.length != mission.visited.length;
      _activePoiMission = mission;
      if (missionChanged) {
        _refreshPoiMarkers();
      }

      final progress = await _poiMissionService.updateProgress(position);
      if (progress != null) {
        if (progress.newlyVisited.isNotEmpty) {
          _showPoiProgressSnack(progress.newlyVisited);
          _activePoiMission = progress.mission;
          _refreshPoiMarkers();
        }
        if (progress.rewardGrantedNow) {
          context
              .read<GameBloc>()
              .add(AddPoints(progress.mission.rewardPoints));
          _showPoiCompleteSnack(progress.mission.rewardPoints);
        }
      }
    } catch (e) {
      print('[engagement] update failed: $e');
    } finally {
      if (!_hasLoadedDrops) {
        _dropsLoading = false;
        if (dropsSynced) {
          _hasLoadedDrops = true;
        }
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  void _syncBoostTicker() {
    if (_activeDropBoost == null || !_activeDropBoost!.isActive) {
      _boostTicker?.cancel();
      _boostTicker = null;
      return;
    }
    _boostTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final boost = _mapDropService.activeBoost;
      if (boost == null || !boost.isActive) {
        _boostTicker?.cancel();
        _boostTicker = null;
      }
      setState(() {
        _activeDropBoost = boost;
      });
    });
  }

  void _refreshDropMarkers() {
    if (_dropMarkerIcon == null && !_isDropIconLoading) {
      unawaited(_ensureDropMarkerIcon());
    }
    final drops = _mapDropService.activeDrops;
    final markers = <Marker>{};
    final circles = <Circle>{};
    for (final drop in drops) {
      markers.add(
        Marker(
          markerId: MarkerId('drop_${drop.id}'),
          position: drop.position,
          icon: _dropMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow,
              ),
          anchor: _dropMarkerIcon != null
              ? const Offset(0.5, 0.5)
              : const Offset(0.5, 1.0),
          zIndex: 16.0,
          onTap: _showDropInfoSheet,
        ),
      );
      circles.add(
        Circle(
          circleId: CircleId('drop_circle_${drop.id}'),
          center: drop.position,
          radius: drop.radiusMeters,
          fillColor: const Color(0xFFFACC15).withOpacity(0.12),
          strokeColor: const Color(0xFFF59E0B).withOpacity(0.6),
          strokeWidth: 1,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _dropMarkers = markers;
        _dropCircles = circles;
      });
    } else {
      _dropMarkers = markers;
      _dropCircles = circles;
    }
  }

  Future<void> _ensureDropMarkerIcon() async {
    if (_dropMarkerIcon != null || _isDropIconLoading) return;
    _isDropIconLoading = true;
    try {
      _dropMarkerIcon = await _createPowerDropMarker();
    } catch (e) {
      print('Failed to build power drop icon: $e');
    } finally {
      _isDropIconLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<BitmapDescriptor> _createPowerDropMarker({int size = 96}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = ui.Offset(size / 2, size / 2);
    final radius = size / 2.0;

    final glowPaint = Paint()
      ..color = const Color(0xFFFCD34D).withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.92, glowPaint);

    final basePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.72, basePaint);

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08;
    canvas.drawCircle(center, radius * 0.62, ringPaint);

    final boltPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final bolt = ui.Path()
      ..moveTo(size * 0.58, size * 0.18)
      ..lineTo(size * 0.38, size * 0.55)
      ..lineTo(size * 0.52, size * 0.55)
      ..lineTo(size * 0.44, size * 0.85)
      ..lineTo(size * 0.70, size * 0.44)
      ..lineTo(size * 0.56, size * 0.44)
      ..close();
    canvas.drawPath(bolt, boltPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  void _refreshPoiMarkers() {
    final mission = _activePoiMission;
    if (mission == null) return;

    final markers = <Marker>{};
    final circles = <Circle>{};
    for (final poi in mission.pois) {
      final visited = mission.visited.contains(poi.id);
      markers.add(
        Marker(
          markerId: MarkerId('poi_${poi.id}'),
          position: poi.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            visited
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueViolet,
          ),
          onTap: _openPoiMissionSheet,
        ),
      );
      circles.add(
        Circle(
          circleId: CircleId('poi_circle_${poi.id}'),
          center: poi.position,
          radius: _poiMissionService.visitRadiusMeters,
          fillColor: visited
              ? const Color(0xFF22C55E).withOpacity(0.12)
              : const Color(0xFF8B5CF6).withOpacity(0.10),
          strokeColor: visited
              ? const Color(0xFF16A34A).withOpacity(0.6)
              : const Color(0xFF7C3AED).withOpacity(0.6),
          strokeWidth: 1,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _poiMarkers = markers;
        _poiCircles = circles;
      });
    } else {
      _poiMarkers = markers;
      _poiCircles = circles;
    }
  }

  void _showDropPickupSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('⚡ Power drop collected! 2x points for 2 minutes'),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPoiProgressSnack(List<Poi> newlyVisited) {
    if (!mounted) return;
    final name = newlyVisited.first.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Visited $name'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPoiCompleteSnack(int rewardPoints) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🏁 Mission complete! +$rewardPoints pts'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDropInfoSheet() {
    if (!mounted) return;
    final boost = _mapDropService.activeBoost;
    final remaining = boost?.remaining ?? Duration.zero;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final hasBoost = boost != null && boost.isActive;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 32),
                const SizedBox(height: 8),
                Text(
                  hasBoost ? 'Power Drop Active' : 'Power Drop',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasBoost
                      ? '2x points for $minutes:${seconds.toString().padLeft(2, '0')}'
                      : 'Walk into the ring to activate 2x points for 2 minutes.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPoiMissionSheet() {
    final mission = _activePoiMission;
    if (mission == null || !mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PoiMissionsSheet(mission: mission),
    );
  }

  Future<void> _openRewardsShop() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RewardsShopScreen(shopService: _rewardsShopService),
      ),
    );
    _refreshMarkerCosmetics();
  }

  void _refreshMarkerCosmetics() {
    final selected = _rewardsShopService.selectedMarkerColor;
    _markerRingColor = selected ?? Colors.white;
    _userAvatarIconCache.clear();
    _userAvatarUrlCache.clear();
    if (mounted) {
      setState(() {});
    }
    if (_lastKnownLocation != null) {
      _updateCurrentUserMarker(_lastKnownLocation!);
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
    appRouteObserver.unsubscribe(this);
    _stepCountStream?.cancel();
    _motionDetection.stopDetection(); // Stop advanced motion detection
    _animController.dispose();
    _buttonAnimController.dispose();
    _mapController?.dispose();
    _audioPlayer.dispose();
    _holdTimer?.cancel();
    _endTimer?.cancel();
    _syncStatusTimer?.cancel();
    _territoryRefreshTimer?.cancel();
    _locationBroadcastTimer?.cancel();
    _liveUserCleanupTimer?.cancel();
    _territoryFetchDebounce?.cancel();
    _mapStartupTimer?.cancel();
    _boostTicker?.cancel();
    _weatherTimer?.cancel();
    _webSocketService.offUserLocation(_handleUserLocation);
    _webSocketService.offTerritoryCaptured(_handleTerritoryCaptured);
    _webSocketService.offTerritorySnapshot(_handleTerritorySnapshot);
    _webSocketService.offDropBoostUpdate(_handleBoostUpdate);
    BackgroundTrackingService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PipAwareWidget(
      child: _buildFullScreen(context),
      pipChild: _buildPipMode(context),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildFullScreen(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<LocationBloc, LocationState>(
            listener: (context, state) {
              if (state is LocationTracking) {
                _lastKnownLocation = LatLng(
                  state.currentPosition.latitude,
                  state.currentPosition.longitude,
                );
                _scheduleTerritoryFetch(_lastKnownLocation!);
                // Update all UI elements in real-time
                _checkRealtimeLoopCapture(state);
                _updateRoutePolyline(state);
                _calculateSpeed(state);
                _updateRouteQuality(state);
                _updateStartPointMarker(state);
                _updateStatsRealTime(state);
                _checkSplitUpdate(state);
                _refreshRoutePreviewFromLocation(_lastKnownLocation);
                _updateCurrentUserMarker(_lastKnownLocation!);
                _handleEngagementUpdate(_lastKnownLocation!);

                // Camera follows user smoothly when tracking is active
                _updateCameraFollow(state);
              } else if (state is LocationIdle && state.lastPosition != null) {
                _lastKnownLocation = LatLng(
                  state.lastPosition!.latitude,
                  state.lastPosition!.longitude,
                );
                _scheduleTerritoryFetch(_lastKnownLocation!);
                _refreshRoutePreviewFromLocation(_lastKnownLocation);
                _updateCurrentUserMarker(_lastKnownLocation!);
                _handleEngagementUpdate(_lastKnownLocation!);
              }
            },
          ),
        ],
        child: Stack(
          children: [
            BlocBuilder<LocationBloc, LocationState>(
              builder: (context, locationState) {
                CameraPosition initialPosition = CameraPosition(
                  target: const LatLng(37.7749, -122.4194), // Default: San Francisco
                  zoom: 15,
                  tilt: _is3DMode ? 45 : 0,
                );

                if (locationState is LocationIdle &&
                    locationState.lastPosition != null) {
                  initialPosition = CameraPosition(
                    target: LatLng(
                      locationState.lastPosition!.latitude,
                      locationState.lastPosition!.longitude,
                    ),
                    zoom: 15,
                    tilt: _is3DMode ? 45 : 0,
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

                    return Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _handlePointerDown,
                      onPointerUp: _handlePointerUp,
                      onPointerCancel: _handlePointerCancel,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: initialPosition,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            mapType: _currentMapType,
                            zoomControlsEnabled: false,
                            tiltGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            polygons: _polygons,
                            polylines: _polylines,
                            markers: {
                              ..._territoryMarkers,
                              ..._dropMarkers,
                              ..._poiMarkers,
                              ..._userMarkersById.values,
                              if (_currentUserMarker != null) _currentUserMarker!,
                            },
                            circles: _getMapCircles(),
                            onCameraMoveStarted: () {
                              if (_activePointers.length >= 2) {
                                _disableFollowOnGesture();
                              }
                            },
                            onMapCreated: (controller) {
                              _mapController = controller;
                              if (!_isMapReady) {
                                setState(() => _isMapReady = true);
                              }
                              if (locationState is LocationIdle &&
                                  locationState.lastPosition != null) {
                                controller.animateCamera(
                                  CameraUpdate.newLatLng(
                                    LatLng(
                                      locationState.lastPosition!.latitude,
                                      locationState.lastPosition!.longitude,
                                    ),
                                  ),
                                );
                              }
                              _startMapDataLoadOnce();
                            },
                            onTap: (LatLng position) {
                              if (_isPlanningRoute) {
                                _addPlannedRoutePoint(position);
                                return;
                              }
                              // Check if tap is inside any activity polygon to show drawer
                              _handleMapTapForActivities(position);
                            },
                            onCameraMove: (position) {
                              // Could generate visible territories here
                            },
                          ),
                          if (_isRaining)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: RainOverlay(
                                  intensity: _rainIntensityFromWeather(),
                                  color: Colors.white,
                                  slant: 0.14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            if (_showOfflineSnapshot && _offlineSnapshotBase64 != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.15),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          base64Decode(_offlineSnapshotBase64!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Offline snapshot',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showLocationGate)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.94),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.my_location,
                              color: AppTheme.accentColor,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _locationGateTitle(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _locationGateMessage(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isCheckingLocationGate)
                            const CircularProgressIndicator(strokeWidth: 2)
                          else ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleLocationGatePrimaryAction,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(_locationGatePrimaryLabel()),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  _checkPreciseLocationAccess(),
                              child: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Minimal top stats bar + sync status
            Positioned(top: 0, left: 0, right: 0, child: _buildTopStatusArea()),

            // Map control buttons (right side)
            Positioned(
              right: 16,
              top: 150,
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
                        Icon(
                          Icons.directions_walk,
                          color: Color(0xFF2196F3),
                          size: 22,
                        ),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _displayedMotionType == MotionType.running
                                  ? Colors.red.shade100
                                  : _displayedMotionType == MotionType.jogging
                                      ? Colors.orange.shade100
                                      : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _displayedMotionType
                                  .toString()
                                  .split('.')
                                  .last
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: _displayedMotionType ==
                                        MotionType.running
                                    ? Colors.red.shade700
                                    : _displayedMotionType == MotionType.jogging
                                        ? Colors.orange.shade700
                                        : Colors.blue.shade700,
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

            if (_shouldShowRouteGuidanceCard())
              Positioned(
                left: 16,
                right: 16,
                bottom: 110,
                child: FadeTransition(
                  opacity: _animController,
                  child: _buildRouteGuidanceCard(),
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

  Future<void> _showTrackingModeSelector(BuildContext context) async {
    final selection = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Start Tracking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.gps_fixed, color: Colors.green),
                title: Text('Real GPS'),
                subtitle: Text('Use live location'),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                leading: Icon(Icons.computer, color: Colors.blue),
                title: Text('Simulation'),
                subtitle: Text('Developer testing mode'),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
    );

    if (selection == null) return;
    setState(() {
      _useSimulation = selection;
    });
    _handleStart(context);
  }

  Future<void> _showGoalSetter(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set Goal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.directions_run, color: Colors.blue),
                title: Text('Distance goal (km)'),
                subtitle: Text(
                  _goalDistanceKm != null
                      ? 'Current: ${_goalDistanceKm!.toStringAsFixed(1)} km'
                      : 'Not set',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final value = await _showGoalInput(context, 'Distance (km)');
                  if (value != null) {
                    setState(() {
                      _goalDistanceKm = value;
                      _goalAreaSqMeters = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.crop_square, color: Colors.purple),
                title: Text('Area goal (m²)'),
                subtitle: Text(
                  _goalAreaSqMeters != null
                      ? 'Current: ${_goalAreaSqMeters!.toStringAsFixed(0)} m²'
                      : 'Not set',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final value = await _showGoalInput(context, 'Area (m²)');
                  if (value != null) {
                    setState(() {
                      _goalAreaSqMeters = value;
                      _goalDistanceKm = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.clear, color: Colors.grey),
                title: Text('Clear goal'),
                onTap: () {
                  setState(() {
                    _goalDistanceKm = null;
                    _goalAreaSqMeters = null;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<double?> _showGoalInput(BuildContext context, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(label),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                Navigator.pop(context, value);
              },
              child: Text('Set'),
            ),
          ],
        );
      },
    );
    return result;
  }

  Widget _buildMinimalStatsBar() {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, gameState) {
        return BlocBuilder<LocationBloc, LocationState>(
          builder: (context, locationState) {
            if (gameState is! GameLoaded) return SizedBox.shrink();

            final isTracking = locationState is LocationTracking;
            final distance = isTracking
                ? locationState.totalDistance / 1000
                : gameState.stats.totalDistanceKm;
            final statusChips = _buildInlineStatusChips();

            return Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: isTracking
                          ? const Color(0xFF0F172A).withOpacity(0.88)
                          : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isTracking
                            ? Colors.white.withOpacity(0.12)
                            : Colors.white.withOpacity(0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                      if (isTracking)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.circle, size: 6, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isTracking) const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatItem(
                          '${distance.toStringAsFixed(2)} km',
                          'Distance',
                          isTracking,
                          isPrimary: true,
                        ),
                      ),
                      _buildHudDivider(isTracking),
                      Expanded(
                        child: _buildStatItem(
                          '${gameState.stats.territoriesCaptured}',
                          'Territories',
                          isTracking,
                        ),
                      ),
                      _buildHudDivider(isTracking),
                      Expanded(
                        child: _buildStatItem(
                          '${gameState.stats.totalPoints}',
                          'Points',
                          isTracking,
                        ),
                      ),
                      _buildHudDivider(isTracking),
                      Expanded(
                        child: _buildStatItem(
                          '${gameState.stats.currentStreak}d',
                          'Streak',
                          isTracking,
                        ),
                      ),
                      ],
                    ),
                  ),
                  if (statusChips is! SizedBox) ...[
                    const SizedBox(height: 8),
                    statusChips,
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopStatusArea() {
    return SafeArea(
      child: FadeTransition(
        opacity: _animController,
        child: _buildMinimalStatsBar(),
      ),
    );
  }

  Widget _buildInlineStatusChips() {
    final chips = <Widget>[
      if (!_isMapReady) _buildLoadingChip('Loading map'),
      if (_allTerritoriesLoading ||
          (_mapDataStarted && !_allTerritoriesLoaded))
        _buildLoadingChip('Loading territories'),
      if (_dropsLoading) _buildLoadingChip('Loading power drops'),
      _buildSyncStatusChip(),
      _buildQualityChip(),
      _buildSplitChip(),
      _buildStreakChip(),
      _buildDropBoostChip(),
      _buildMissionChip(),
      _buildBadgeChip(),
    ];

    final visibleChips = chips.where((chip) {
      if (chip is SizedBox) {
        final width = chip.width ?? 0;
        final height = chip.height ?? 0;
        return width != 0 || height != 0 || chip.child != null;
      }
      return true;
    }).toList();

    if (visibleChips.isEmpty) {
      return const SizedBox.shrink();
    }

    final rowChildren = <Widget>[];
    for (final chip in visibleChips) {
      if (rowChildren.isNotEmpty) {
        rowChildren.add(const SizedBox(width: 6));
      }
      rowChildren.add(chip);
    }

    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: rowChildren,
        ),
      ),
    );
  }

  Widget _buildSyncStatusChip() {
    if (_pendingSyncCount == 0 && !_isSyncing) {
      return const SizedBox.shrink();
    }

    final bool hasPending = _pendingSyncCount > 0;
    final String label = hasPending
        ? (_isSyncing
            ? 'Syncing $_pendingSyncCount'
            : 'Saved offline $_pendingSyncCount')
        : 'Syncing...';
    final Color bgColor =
        _isSyncing ? const Color(0xFF1E3A8A) : const Color(0xFF9A3412);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSyncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(Icons.cloud_off, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    bool isTracking, {
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isPrimary ? 16 : 14,
            fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w800,
            color: isTracking
                ? Colors.white
                : (isPrimary ? const Color(0xFF0F172A) : Colors.black87),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isTracking ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildHudDivider(bool isTracking) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isTracking ? Colors.white12 : Colors.grey.shade300,
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
      print(
        '⚠️ Route update skipped: need at least 2 points, have ${state.routePoints.length}',
      );
      return;
    }

    final now = DateTime.now();
    if (_lastRouteRenderAt != null &&
        now.difference(_lastRouteRenderAt!) < _routeRenderThrottle) {
      return;
    }
    _lastRouteRenderAt = now;

    final rawPoints =
        state.routePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final points = _smoothRouteForDisplay(rawPoints);

    setState(() {
      _polylines.removeWhere(
        (polyline) => !polyline.polylineId.value.startsWith('route_plan'),
      );
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_outline'),
          points: points,
          color: Colors.black.withOpacity(0.25),
          width: 10,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Color(0xFF00B0FF), // Smooth cyan-blue
          width: 6,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    });

    print(
      '✅ Route updated: ${points.length} points, ${(state.totalDistance / 1000).toStringAsFixed(2)} km',
    );
  }

  Widget _buildQualityChip() {
    if (_routeQualityScore <= 0) {
      return const SizedBox.shrink();
    }

    final color = _routeQualityScore >= 85
        ? const Color(0xFF059669)
        : _routeQualityScore >= 70
            ? const Color(0xFF2563EB)
            : _routeQualityScore >= 55
                ? const Color(0xFFF59E0B)
                : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'GPS ${_routeQualityLabel.toUpperCase()} ${_routeQualityScore.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitChip() {
    if (_lastSplitPace == null || _splitIndex == 0) {
      return const SizedBox.shrink();
    }

    final splitLabel = _lastSplitDuration != null
        ? _formatDurationShort(_lastSplitDuration!)
        : '--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Split ${_splitIndex} • ${_lastSplitPace!}/km (${splitLabel})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakChip() {
    if (_localStreakDays == 0 && _bestStreakDays == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            'Streak ${_localStreakDays}d • Best ${_bestStreakDays}d',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDurationShort(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<LatLng> _smoothRouteForDisplay(List<LatLng> points) {
    if (points.length < 3) return points;
    final simplified = _simplifyRoute(points, 1.5);
    final smoothed = _chaikinSmooth(simplified, iterations: 2);
    return _limitLatLngPoints(smoothed, maxPoints: 1800);
  }

  List<LatLng> _chaikinSmooth(
    List<LatLng> points, {
    int iterations = 1,
  }) {
    var current = List<LatLng>.from(points);
    for (var i = 0; i < iterations; i++) {
      if (current.length < 3) break;
      final next = <LatLng>[];
      next.add(current.first);
      for (var j = 0; j < current.length - 1; j++) {
        final p0 = current[j];
        final p1 = current[j + 1];
        final q = LatLng(
          0.75 * p0.latitude + 0.25 * p1.latitude,
          0.75 * p0.longitude + 0.25 * p1.longitude,
        );
        final r = LatLng(
          0.25 * p0.latitude + 0.75 * p1.latitude,
          0.25 * p0.longitude + 0.75 * p1.longitude,
        );
        next.add(q);
        next.add(r);
      }
      next.add(current.last);
      current = next;
    }
    return current;
  }

  void _updateCameraFollow(LocationTracking state) {
    if (_mapController == null ||
        _trackingState != TrackingState.started ||
        !_followUser) {
      return;
    }

    final now = DateTime.now();
    if (_lastCameraUpdate != null &&
        now.difference(_lastCameraUpdate!) < _cameraUpdateThrottle) {
      return;
    }
    _lastCameraUpdate = now;

    final rawTarget = LatLng(
      state.currentPosition.latitude,
      state.currentPosition.longitude,
    );

    _smoothedCameraTarget ??= rawTarget;
    final speedFactor = (_currentSpeed / 20).clamp(0.0, 1.0);
    final baseAlpha = _is3DMode ? 0.3 : 0.2;
    final alpha = (baseAlpha + (0.2 * speedFactor)).clamp(0.18, 0.5);

    _smoothedCameraTarget = LatLng(
      _smoothedCameraTarget!.latitude +
          (rawTarget.latitude - _smoothedCameraTarget!.latitude) * alpha,
      _smoothedCameraTarget!.longitude +
          (rawTarget.longitude - _smoothedCameraTarget!.longitude) * alpha,
    );

    final bearing = _calculateBearingFromRoute(state);
    if (bearing != null) {
      _smoothedCameraBearing = _smoothedCameraBearing == null
          ? bearing
          : _lerpAngle(_smoothedCameraBearing!, bearing, 0.25);
    }

    final tilt = _is3DMode ? 55.0 : 25.0;
    final zoom = _is3DMode ? 18.5 : 17.5;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _smoothedCameraTarget!,
          zoom: zoom,
          tilt: tilt,
          bearing: _smoothedCameraBearing ?? 0.0,
        ),
      ),
    );
  }

  double? _calculateBearingFromRoute(LocationTracking state) {
    if (state.routePoints.length < 2) return null;
    final prev = state.routePoints[state.routePoints.length - 2];
    final last = state.routePoints.last;
    final from = LatLng(prev.latitude, prev.longitude);
    final to = LatLng(last.latitude, last.longitude);
    return _calculateBearing(from, to);
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) -
        sin(lat1) * cos(lat2) * cos(dLng);
    final bearing = atan2(y, x) * 180.0 / pi;
    return (bearing + 360.0) % 360.0;
  }

  double _lerpAngle(double from, double to, double t) {
    final delta = ((to - from + 540) % 360) - 180;
    return (from + delta * t + 360) % 360;
  }

  double _toRadians(double deg) => deg * pi / 180.0;

  void _updateStartPointMarker(LocationTracking state) {
    // Disabled: no start point circle.
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
    if (territories.isEmpty ||
        territories.length == _lastLoadedTerritoryCount) {
      return; // Skip - already processed
    }

    // Load and display all captured territories as filled areas
    final currentUserId = _currentUserIdFromAuth() ?? 'current_user';

    final pendingOwnerMarkers = <Map<String, dynamic>>[];
    setState(() {
      _polygons.clear();
      _territoryMarkers.clear();

      // Group territories by owner to create filled areas
      Map<String, List<app.Territory>> territoriesByOwner = {};
      for (final territory in territories) {
        if (territory.ownerId != null) {
          territoriesByOwner
              .putIfAbsent(territory.ownerId!, () => [])
              .add(territory);
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
        final isOwnTerritory = ownerId == currentUserId;

        if (isOwnTerritory) {
          // Your territory - green
          fillColor = Color(0xFF4CAF50).withOpacity(_territoryFillOpacity);
          strokeColor = Color(0xFF4CAF50).withOpacity(0.7);
        } else {
          // Other player's territory - red
          fillColor = Color(0xFFE53935).withOpacity(_territoryFillOpacity);
          strokeColor = Color(0xFFE53935).withOpacity(0.7);
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
        final markerId = 'label_$ownerId';
        final center = LatLng(centerLat, centerLng);
        final captureCount = ownerTerritories.length;
        final pointsTotal = ownerTerritories.fold<int>(
          0,
          (sum, territory) => sum + territory.points,
        );
        final latestCapturedAt = ownerTerritories
            .map((territory) => territory.capturedAt)
            .reduce(
              (current, next) => current.isAfter(next) ? current : next,
            );
        DateTime? latestBattleAt;
        for (final territory in ownerTerritories) {
          final battleAt = territory.lastBattleAt;
          if (battleAt == null) continue;
          if (latestBattleAt == null || battleAt.isAfter(latestBattleAt!)) {
            latestBattleAt = battleAt;
          }
        }
        final areaSqMeters = _calculatePolygonAreaSqMeters(allPoints);
        final cachedAvatarSource = _extractAvatarFromMap(
          _userProfileCache[ownerId],
        );
        final ownerAvatarSource =
            cachedAvatarSource ??
            (isOwnTerritory ? _currentUserAvatarSource() : null);
        final ownerOnTap = () {
          _showTerritoryInfo(
            ownerName: ownerName,
            captureCount: captureCount,
            isOwn: isOwnTerritory,
            points: pointsTotal,
            capturedAt: latestCapturedAt,
            lastBattleAt: latestBattleAt,
            areaSqMeters: areaSqMeters,
            avatarSource: ownerAvatarSource,
          );
        };
        _territoryMarkers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: center,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            onTap: ownerOnTap,
          ),
        );
        pendingOwnerMarkers.add({
          'markerId': markerId,
          'position': center,
          'ownerId': ownerId,
          'ownerName': ownerName,
          'captureCount': captureCount,
          'pointsTotal': pointsTotal,
          'capturedAt': latestCapturedAt,
          'lastBattleAt': latestBattleAt,
          'areaSqMeters': areaSqMeters,
          'isOwn': isOwnTerritory,
          'avatarSource': ownerAvatarSource,
        });
      }
    });

    for (final pending in pendingOwnerMarkers) {
      final ownerId = pending['ownerId']?.toString();
      if (ownerId == null || ownerId.isEmpty) continue;
      final ownerName = pending['ownerName']?.toString() ?? 'Unknown';
      final captureCount = _toIntSafe(pending['captureCount'], fallback: 1);
      final pointsTotalRaw = pending['pointsTotal'];
      final pointsTotal =
          pointsTotalRaw == null ? null : _toIntSafe(pointsTotalRaw);
      final capturedAt = pending['capturedAt'] as DateTime?;
      final lastBattleAt = pending['lastBattleAt'] as DateTime?;
      final areaSqMeters = _toDoubleSafe(pending['areaSqMeters']);
      final isOwn = pending['isOwn'] == true;
      final baseAvatarSource = pending['avatarSource']?.toString();

      void showSheet(String? avatar) {
        _showTerritoryInfo(
          ownerName: ownerName,
          captureCount: captureCount,
          isOwn: isOwn,
          points: pointsTotal,
          capturedAt: capturedAt,
          lastBattleAt: lastBattleAt,
          areaSqMeters: areaSqMeters,
          avatarSource: avatar,
        );
      }

      if (baseAvatarSource != null && baseAvatarSource.isNotEmpty) {
        _scheduleCapturedAreaAvatarUpdate(
          markerId: pending['markerId'] as String,
          position: pending['position'] as LatLng,
          avatarCacheKey: ownerId,
          avatarSource: baseAvatarSource,
          onTap: () => showSheet(baseAvatarSource),
        );
      }

      _ensureUserProfile(ownerId).then((profile) {
        final resolvedAvatar = _extractAvatarFromMap(profile) ??
            (ownerId == _currentUserIdFromAuth()
                ? _currentUserAvatarSource()
                : null);
        if (resolvedAvatar == null || resolvedAvatar.isEmpty) return;
        _scheduleCapturedAreaAvatarUpdate(
          markerId: pending['markerId'] as String,
          position: pending['position'] as LatLng,
          avatarCacheKey: ownerId,
          avatarSource: resolvedAvatar,
          onTap: () => showSheet(resolvedAvatar),
        );
      });
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _checkRealtimeLoopCapture(LocationTracking state) {
    if (_trackingState != TrackingState.started) return;
    if (state.routePoints.length < 3) return;

    if (_loopStartIndex >= state.routePoints.length) {
      _loopStartIndex = max(0, state.routePoints.length - 1);
      _loopStartDistanceMeters = state.totalDistance;
    }

    final startPoint = state.routePoints[_loopStartIndex];
    final lastPoint = state.routePoints.last;
    final distanceToStart =
        _calculateDistanceBetweenPoints(startPoint, lastPoint);
    _distanceToStart = distanceToStart;

    if (distanceToStart < 150 &&
        state.routePoints.length - _loopStartIndex >= 3) {
      final segmentLatLngs = state.routePoints
          .sublist(_loopStartIndex)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      if (segmentLatLngs.length >= 3) {
        _estimatedAreaSqMeters = _calculatePolygonAreaSqMeters(segmentLatLngs);
      }
    } else if (_estimatedAreaSqMeters != 0.0 && distanceToStart > 200) {
      _estimatedAreaSqMeters = 0.0;
    }

    final distanceSinceLoopStart =
        state.totalDistance - _loopStartDistanceMeters;
    if (distanceToStart > 100) return;
    if (distanceSinceLoopStart < 100) return;
    if (_loopCaptureInFlight) return;
    if (_lastLoopCaptureAt != null &&
        DateTime.now().difference(_lastLoopCaptureAt!) <
            const Duration(seconds: 8)) {
      return;
    }

    final segmentPoints = state.routePoints.sublist(_loopStartIndex);
    if (segmentPoints.length < 3) return;
    _captureLoopSegmentRealtime(state, segmentPoints);
  }

  Future<void> _captureLoopSegmentRealtime(
    LocationTracking state,
    List<Position> segmentPoints,
  ) async {
    if (_loopCaptureInFlight) return;
    _loopCaptureInFlight = true;
    var didCapture = false;

    try {
      final routeLatLngs =
          segmentPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
      if (routeLatLngs.length < 3) return;

      final simplified = _simplifyRoute(routeLatLngs, 3.0);
      if (simplified.length < 3) return;

      double minLat = simplified.first.latitude;
      double maxLat = simplified.first.latitude;
      double minLng = simplified.first.longitude;
      double maxLng = simplified.first.longitude;

      for (final point in simplified) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      const double metersPerDegreeLat = 111000.0;
      final avgLat = (minLat + maxLat) / 2;
      final metersPerDegreeLng = metersPerDegreeLat * cos(avgLat * pi / 180);
      final heightMeters = (maxLat - minLat) * metersPerDegreeLat;
      final widthMeters = (maxLng - minLng) * metersPerDegreeLng;
      final boundingAreaSqMeters = heightMeters * widthMeters;
      if (boundingAreaSqMeters < 100) {
        return;
      }

      final capturedHexIds = <String>{};
      const double latStep = 0.00018; // ~20 meters latitude
      final double lngStep = 0.00018 / cos(avgLat * pi / 180);

      for (double lat = minLat; lat <= maxLat; lat += latStep) {
        for (double lng = minLng; lng <= maxLng; lng += lngStep) {
          if (_isPointInPolygon(LatLng(lat, lng), simplified)) {
            capturedHexIds.add(TerritoryGridHelper.getHexId(lat, lng));
          }
        }
      }

      if (capturedHexIds.isEmpty) return;

      setState(() {
        _currentSessionTerritories += 1;
        _capturedHexIds.addAll(capturedHexIds);
        _territoryRoutePoints = simplified;
      });

      _showCapturedArea(simplified);

      final loopId = _uuid.v4();
      final hexCoordinates = <Map<String, double>>[];
      for (final hexId in capturedHexIds) {
        final (centerLat, centerLng) = TerritoryGridHelper.getHexCenter(hexId);
        hexCoordinates.add({'lat': centerLat, 'lng': centerLng});
      }

      final limitedTerritoryPoints = _limitLatLngPoints(simplified);
      final routePointsArray = [
        limitedTerritoryPoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      ];

      final payload = {
        'hexIds': capturedHexIds.toList(),
        'coordinates': hexCoordinates,
        'captureSessionId': loopId,
        'routePoints': routePointsArray,
      };

      try {
        final territoryApiService = di.getIt<TerritoryApiService>();
        await territoryApiService.captureTerritoriesPayload(payload);
        _reportedHexIds.addAll(capturedHexIds);
        didCapture = true;
      } catch (e) {
        try {
          await _offlineSyncService.queueTerritoryPayload(payload);
          _reportedHexIds.addAll(capturedHexIds);
          _triggerBackgroundSync();
          didCapture = true;
        } catch (queueError) {
          print('[warn] Failed to queue realtime territory payload: $queueError');
        }
      }
    } finally {
      if (didCapture) {
        _loopStartIndex = max(0, state.routePoints.length - 1);
        _loopStartDistanceMeters = state.totalDistance;
        _distanceToStart = double.infinity;
        _estimatedAreaSqMeters = 0.0;
      }
      _lastLoopCaptureAt = DateTime.now();
      _loopCaptureInFlight = false;
    }
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

    print(
      '🔍 Distance check: current=${currentDistanceKm.toStringAsFixed(4)} km, last=${_lastDistanceUpdate.toStringAsFixed(4)} km, delta=${distanceDelta.toStringAsFixed(4)} km',
    );

    // REAL-TIME: Update when distance changes by at least 5 meters
    if (distanceDelta >= 0.005) {
      _lastDistanceUpdate = currentDistanceKm;

      // Update distance in GameBloc
      print('📊 Updating GameBloc: +${distanceDelta.toStringAsFixed(3)} km');
      context.read<GameBloc>().add(UpdateDistance(distanceDelta));

      // Award points based on distance (100 points per km, boosted by drops)
      final boostMultiplier = _mapDropService.activeBoost?.multiplier ?? 1;
      final pointsDelta = (distanceDelta * 100 * boostMultiplier).round();
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

    _maybeUpdateHomeWidget(state);
  }

  void _maybeUpdateHomeWidget(LocationTracking state) {
    final now = DateTime.now();
    if (_lastWidgetUpdateAt != null &&
        now.difference(_lastWidgetUpdateAt!) < _widgetUpdateThrottle) {
      return;
    }

    final distanceKm = state.totalDistance / 1000;
    final sessionSteps = max(0, _steps - _sessionStartSteps);
    final goalKm = _goalDistanceKm ?? 5.0;
    final progressPercent =
        goalKm > 0 ? ((distanceKm / goalKm) * 100).round() : 0;

    HomeWidgetService.updateStats(
      distanceKm: distanceKm,
      steps: sessionSteps,
      progressPercent: progressPercent.clamp(0, 100).toInt(),
    );
    _lastWidgetUpdateAt = now;
  }

  void _updateBackgroundNotification(LocationTracking state) {
    // Determine speed category from current speed
    String speedCategory = 'Still';
    if (_currentSpeed > 0 && _currentSpeed < 6)
      speedCategory = 'Walking';
    else if (_currentSpeed >= 6 && _currentSpeed < 10)
      speedCategory = 'Jogging';
    else if (_currentSpeed >= 10) speedCategory = 'Running';

    // Use motion detection if available
    if (_motionType != MotionType.stationary) {
      speedCategory = _motionType.toString().split('.').last.toUpperCase();
    }

    // Update with CURRENT SESSION data (event-driven, no timer)
    BackgroundTrackingService.updateNotification(
      distance: state.totalDistance / 1000,
      territories:
          _currentSessionTerritories, // Show territories captured THIS session
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
          content: Text(
            'No route recorded. Start tracking to capture territories!',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return 0;
    }

    // Require minimum distance before allowing capture
    final distanceKm = locationState.totalDistance / 1000;
    if (distanceKm < 0.1) {
      // Must move at least 100 meters
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
        .map(
          (p) => (
            position: LatLng(p.latitude, p.longitude),
            timestamp: p.timestamp,
          ),
        )
        .toList();

    final validationResult = AntiCheatValidator.validateRoute(
      routeWithTimestamps,
    );
    if (!validationResult.isValid) {
      print(
        '⛔ ANTI-CHEAT: Route failed validation - ${validationResult.violation}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Route validation failed: ${validationResult.violation}',
                ),
              ),
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
      print(
        '⚠️ Route perimeter ($routePerimeter m) is much larger than distance traveled (${distanceKm * 1000} m)',
      );
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
    print(
      '📊 Route simplified: ${rawRouteLatLngs.length} → ${routeLatLngs.length} points',
    );

    // Check if route forms a closed loop (start and end are close)
    final distanceToStart = _calculateDistanceBetweenPoints(
      locationState.routePoints.first,
      locationState.routePoints.last,
    );

    // Allow all distances - always capture territory if route has enough points
    final isClosedLoop = locationState.routePoints.length >= 3;

    print(
      '🔍 Loop check: ${locationState.routePoints.length} points, distance to start: ${distanceToStart.toStringAsFixed(1)}m, closed: $isClosedLoop',
    );

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

      print(
        '📐 Bounding box: ${widthMeters.toStringAsFixed(1)}m x ${heightMeters.toStringAsFixed(1)}m = ${boundingAreaSqMeters.toStringAsFixed(0)} m²',
      );

      if (boundingAreaSqMeters < 100) {
        // 10m x 10m = 100 m² minimum
        print(
          '⚠️ Loop too small to capture area: ${boundingAreaSqMeters.toStringAsFixed(0)} m² < 100 m²',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Loop area too small! Current: ${boundingAreaSqMeters.toStringAsFixed(0)} m² (need 100+ m²)',
            ),
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
      final lngStep =
          0.00018 / cos(avgLat * pi / 180); // Compensate for latitude

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
                  final recaptured = existingTerritory.recaptureBy(
                    currentUserId,
                    currentUserName,
                  );
                  recapturedTerritories.add(recaptured);
                  context.read<TerritoryBloc>().add(
                        CaptureTerritoryEvent(recaptured),
                      );
                }
                // Skip if already owned by current user
              } else {
                // New territory capture
                // Note: createTerritory will compute proper hex center from lat/lng
                final territory = TerritoryGridHelper.createTerritory(
                  lat,
                  lng,
                  ownerId: currentUserId,
                  ownerName: currentUserName,
                );
                newTerritories.add(territory);
                context.read<TerritoryBloc>().add(
                      CaptureTerritoryEvent(territory),
                    );
              }
            }
          }
        }
      }

      print(
        '📊 Scanned $scannedPoints points, $capturedPoints inside polygon, ${capturedHexIds.length} unique hexagons',
      );
    } else {
      print(
        '⚠️ Path not closed - distance to start: ${distanceToStart.toStringAsFixed(1)}m (need < 100m)',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Return to your starting point to capture the enclosed area!\nCurrent distance: ${distanceToStart.toStringAsFixed(0)}m (need < 100m)',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return 0; // Don't capture anything if not a closed loop
    }

    // Successfully captured area with closed loop
    // Store hex IDs for backend tracking but return 1 territory (the completed loop)
    final totalHexagonsCaptured =
        newTerritories.length + recapturedTerritories.length;
    if (totalHexagonsCaptured > 0) {
      // Points are now distance-based, calculated in _stopTracking()
      // Just fire 1 territory capture event (the loop)
      context.read<GameBloc>().add(TerritoryCapture());

      // Update session territories count
      setState(() {
        _currentSessionTerritories = 1; // 1 loop = 1 territory
        // CRITICAL: Store captured hex IDs for backend saving
        _capturedHexIds.addAll(capturedHexIds);
      });

      print(
        '💾 Stored ${capturedHexIds.length} hex IDs for backend save. Total session: ${_capturedHexIds.length}',
      );
      print(
        '🎯 Completed 1 territory (loop with ${totalHexagonsCaptured} hexagons)',
      );
    }

    print(
      '✅ Captured ${newTerritories.length} new hexagons, ${recapturedTerritories.length} recaptured (${isClosedLoop ? "AREA" : "PATH"}), ${distanceKm.toStringAsFixed(2)} km',
    );

    // Return 1 territory if we completed a loop, 0 otherwise
    return totalHexagonsCaptured > 0 ? 1 : 0;
  }

  // Fill captured area with transparent color
  // Shows EXACTLY what you walked: circle = filled circle, zigzag = filled zigzag
  void _showCapturedArea(List<LatLng> routePoints) {
    if (routePoints.length < 3) return;

    // Generate unique ID for this captured area using timestamp
    final areaId = DateTime.now().millisecondsSinceEpoch.toString();
    double sumLat = 0;
    double sumLng = 0;
    for (final point in routePoints) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    final center = LatLng(
      sumLat / routePoints.length,
      sumLng / routePoints.length,
    );

    setState(() {
      // DON'T clear existing polygons - just add the new one!
      // _polygons.clear();  // REMOVED - this was deleting previous captures
      // _territoryMarkers.clear();  // REMOVED

      // Fill the area you walked with transparent green
      _polygons.add(
        Polygon(
          polygonId: PolygonId('captured_area_$areaId'),
          points: routePoints,
          fillColor:
              const Color(0xFF4CAF50).withOpacity(_capturedAreaFillOpacity),
          strokeColor: const Color(0xFF4CAF50).withOpacity(0.5),
          strokeWidth: 2,
          consumeTapEvents: true,
          onTap: () {
            final authState = context.read<AuthBloc>().state;
            final ownerName =
                authState is Authenticated ? authState.user.name : 'You';
            final areaSqMeters = _calculatePolygonAreaSqMeters(routePoints);
            _showTerritoryInfo(
              ownerName: ownerName,
              captureCount: 1,
              isOwn: true,
              capturedAt: DateTime.now(),
              areaSqMeters: areaSqMeters,
              avatarSource: _currentUserAvatarSource(),
            );
          },
        ),
      );

      // Show username in center of captured area
      if (routePoints.isNotEmpty) {
        final authState = context.read<AuthBloc>().state;
        final ownerName =
            authState is Authenticated ? authState.user.name : 'You';
        final areaSqMeters = _calculatePolygonAreaSqMeters(routePoints);
        _territoryMarkers.add(
          Marker(
            markerId: MarkerId('username_label_$areaId'),
            position: center,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            onTap: () {
              _showTerritoryInfo(
                ownerName: ownerName,
                captureCount: 1,
                isOwn: true,
                capturedAt: DateTime.now(),
                areaSqMeters: areaSqMeters,
                avatarSource: _currentUserAvatarSource(),
              );
            },
          ),
        );
      }
    });

    final avatarSource = _currentUserAvatarSource();
    final cacheKey = _currentUserIdFromAuth() ?? 'current_user';
    if (avatarSource != null && avatarSource.isNotEmpty) {
      _scheduleCapturedAreaAvatarUpdate(
        markerId: 'username_label_$areaId',
        position: center,
        avatarCacheKey: cacheKey,
        avatarSource: avatarSource,
        onTap: () {
          final authState = context.read<AuthBloc>().state;
          final ownerName =
              authState is Authenticated ? authState.user.name : 'You';
          final areaSqMeters = _calculatePolygonAreaSqMeters(routePoints);
          _showTerritoryInfo(
            ownerName: ownerName,
            captureCount: 1,
            isOwn: true,
            capturedAt: DateTime.now(),
            areaSqMeters: areaSqMeters,
            avatarSource: avatarSource,
          );
        },
      );
    }

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
    final isTracking = _trackingState != TrackingState.stopped;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showAdvancedControls) ...[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: _buildAdvancedControlsPanel(key: const ValueKey('panel')),
          ),
          const SizedBox(width: 10),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onNavigateHome != null && isTracking) ...[
              _buildControlButton(
                icon: Icons.home,
                label: 'Home',
                isActive: false,
                onTap: widget.onNavigateHome!,
              ),
              SizedBox(height: 8),
            ],
            _buildControlButton(
              icon: Icons.my_location,
              label: 'Me',
              isActive: false,
              onTap: _centerOnUser,
            ),
            SizedBox(height: 8),
            _buildControlButton(
              icon: _showAdvancedControls ? Icons.expand_less : Icons.tune,
              label: _showAdvancedControls ? 'Less' : 'More',
              isActive: _showAdvancedControls,
              onTap: () {
                setState(() {
                  _showAdvancedControls = !_showAdvancedControls;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedControlsPanel({Key? key}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxPanelHeight = max(200.0, min(340.0, screenHeight * 0.45));
    return ConstrainedBox(
      key: key,
      constraints: BoxConstraints(maxHeight: maxPanelHeight, maxWidth: 190),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCompactControlButton(
              icon: Icons.threed_rotation,
              label: '3D',
              isActive: _is3DMode,
              onTap: _toggle3DMode,
            ),
            _buildCompactControlButton(
              icon: Icons.alt_route,
              label: 'Routes',
              isActive: _selectedRoute != null,
              onTap: _openRoutesSheet,
            ),
            _buildCompactControlButton(
              icon: Icons.layers,
              label: 'View',
              isActive: _currentMapType != MapType.normal,
              onTap: _toggleMapType,
            ),
            _buildCompactControlButton(
              icon: Icons.whatshot,
              label: 'Heat',
              isActive: _showHeatmap,
              onTap: _toggleHeatmap,
            ),
            _buildCompactControlButton(
              icon: Icons.flag,
              label: 'Missions',
              isActive: _activePoiMission != null &&
                  _activePoiMission!.visited.length <
                      _activePoiMission!.pois.length,
              onTap: _openPoiMissionSheet,
            ),
            _buildCompactControlButton(
              icon: Icons.storefront,
              label: 'Shop',
              isActive: false,
              onTap: _openRewardsShop,
            ),
            _buildCompactControlButton(
              icon: Icons.flag,
              label: 'Goal',
              isActive: _goalDistanceKm != null || _goalAreaSqMeters != null,
              onTap: () => _showGoalSetter(context),
            ),
            _buildCompactControlButton(
              icon: Icons.eco,
              label: 'Eco',
              isActive: _batterySaverEnabled,
              onTap: () {
                setState(() {
                  _batterySaverEnabled = !_batterySaverEnabled;
                });
              },
            ),
            _buildCompactControlButton(
              icon: Icons.cloud_sync,
              label: 'Sync',
              isActive: _pendingSyncCount > 0 || _isSyncing,
              onTap: _openSyncStatus,
            ),
            _buildCompactControlButton(
              icon: Icons.image,
              label: 'Offline',
              isActive: _showOfflineSnapshot,
              onTap: () {
                setState(() {
                  _showOfflineSnapshot = !_showOfflineSnapshot;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.black87,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _centerOnUser() async {
    if (_mapController == null) return;

    if (mounted) {
      setState(() {
        _followUser = true;
      });
    } else {
      _followUser = true;
    }

    LatLng? target;
    final locationState = context.read<LocationBloc>().state;

    if (locationState is LocationTracking) {
      target = LatLng(
        locationState.currentPosition.latitude,
        locationState.currentPosition.longitude,
      );
    } else if (locationState is LocationIdle &&
        locationState.lastPosition != null) {
      target = LatLng(
        locationState.lastPosition!.latitude,
        locationState.lastPosition!.longitude,
      );
    } else {
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        target = LatLng(position.latitude, position.longitude);
      } catch (e) {
        print('❌ Failed to get current location: $e');
      }
    }

    if (target != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: _is3DMode ? 18 : 16,
            tilt: _is3DMode ? 45 : 0,
            bearing: 0,
          ),
        ),
      );
    }
  }

  List<LatLng> _buildPlannedRoutePreview(List<LatLng> points) {
    if (points.length < 3) return List<LatLng>.from(points);
    final simplified = _simplifyRoute(points, 2.0);
    return simplified.length >= 2 ? simplified : List<LatLng>.from(points);
  }

  Future<void> _addCurrentLocationToPlan() async {
    if (!_isPlanningRoute) return;
    LatLng? target = _lastKnownLocation;
    if (target == null) {
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        target = LatLng(position.latitude, position.longitude);
      } catch (e) {
        print('❌ Failed to get current location: $e');
      }
    }

    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
      }
      return;
    }

    _lastKnownLocation = target;
    _addPlannedRoutePoint(target);
  }

  void _addPlannedRoutePoint(LatLng point) {
    setState(() {
      _plannedRoutePoints.add(point);
      _plannedRoutePreviewPoints = _buildPlannedRoutePreview(
        _plannedRoutePoints,
      );
    });
    _refreshRoutePreviewFromLocation(_lastKnownLocation, force: true);
  }

  void _undoPlannedRoutePoint() {
    if (_plannedRoutePoints.isEmpty) return;
    setState(() {
      _plannedRoutePoints.removeLast();
      _plannedRoutePreviewPoints = _buildPlannedRoutePreview(
        _plannedRoutePoints,
      );
    });
    _refreshRoutePreviewFromLocation(_lastKnownLocation, force: true);
  }

  void _clearPlannedRoute() {
    setState(() {
      _plannedRoutePoints.clear();
      _plannedRoutePreviewPoints.clear();
    });
    _refreshRoutePreviewFromLocation(_lastKnownLocation, force: true);
  }

  void _previewRoute(SavedRoute route) {
    setState(() {
      _selectedRoute = route;
    });
    _refreshRoutePreviewFromLocation(_lastKnownLocation, force: true);
  }

  List<LatLng> _getActiveRoutePoints() {
    if (_selectedRoute != null && _selectedRoute!.points.length >= 2) {
      return _selectedRoute!.points;
    }
    if (_plannedRoutePreviewPoints.isNotEmpty) {
      return _plannedRoutePreviewPoints;
    }
    return _plannedRoutePoints;
  }

  void _refreshRoutePreviewFromLocation(
    LatLng? location, {
    bool force = false,
  }) {
    final routePoints = _getActiveRoutePoints();
    if (routePoints.length < 2) {
      if (!mounted) return;
      setState(() {
        _applyRouteGuidancePolylines(base: const []);
        _routeTotalMeters = 0.0;
        _routeRemainingMeters = 0.0;
        _routeDeviationMeters = 0.0;
        _routeEta = null;
      });
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRoutePreviewUpdate != null &&
        now.difference(_lastRoutePreviewUpdate!) < _routePreviewThrottle) {
      return;
    }
    _lastRoutePreviewUpdate = now;

    if (!_isRealtimeRouteEnabled || location == null) {
      final totalMeters = _calculateRouteDistanceMeters(routePoints);
      final eta = _estimateEta(totalMeters);
      if (!mounted) return;
      setState(() {
        _applyRouteGuidancePolylines(base: routePoints);
        _routeTotalMeters = totalMeters;
        _routeRemainingMeters = totalMeters;
        _routeDeviationMeters = 0.0;
        _routeEta = eta;
      });
      return;
    }

    final projection = _projectPointOntoRoute(location, routePoints);
    final remainingMeters =
        (projection.totalMeters - projection.distanceFromStartMeters).clamp(
      0.0,
      projection.totalMeters,
    );
    final progressPoints = _buildProgressPoints(
      routePoints,
      projection.segmentIndex,
      projection.projectedPoint,
    );
    final remainingPoints = _buildRemainingPoints(
      routePoints,
      projection.segmentIndex,
      projection.projectedPoint,
    );
    final eta = _estimateEta(remainingMeters);

    if (!mounted) return;
    setState(() {
      _applyRouteGuidancePolylines(
        base: routePoints,
        progress: progressPoints,
        remaining: remainingPoints,
      );
      _routeTotalMeters = projection.totalMeters;
      _routeRemainingMeters = remainingMeters;
      _routeDeviationMeters = projection.distanceToRouteMeters;
      _routeEta = eta;
    });
  }

  void _applyRouteGuidancePolylines({
    required List<LatLng> base,
    List<LatLng> progress = const [],
    List<LatLng> remaining = const [],
  }) {
    _polylines.removeWhere((polyline) {
      final id = polyline.polylineId.value;
      return id == 'route_plan' ||
          id == 'route_preview' ||
          id == 'route_plan_base' ||
          id == 'route_plan_progress' ||
          id == 'route_plan_remaining';
    });

    if (base.length >= 2) {
      final showDashed = _selectedRoute == null;
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_plan_base'),
          points: base,
          color: Colors.blueGrey.withOpacity(0.55),
          width: 5,
          patterns: showDashed
              ? [PatternItem.dash(12), PatternItem.gap(8)]
              : const <PatternItem>[],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    if (progress.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_plan_progress'),
          points: progress,
          color: Colors.green.shade600,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    if (remaining.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_plan_remaining'),
          points: remaining,
          color: Colors.blueAccent.withOpacity(0.9),
          width: 5,
          patterns: [PatternItem.dash(10), PatternItem.gap(6)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }
  }

  List<LatLng> _buildProgressPoints(
    List<LatLng> route,
    int segmentIndex,
    LatLng projectedPoint,
  ) {
    if (route.isEmpty) return [];
    final points = <LatLng>[];
    points.addAll(route.take(segmentIndex + 1));
    if (points.isEmpty ||
        points.last.latitude != projectedPoint.latitude ||
        points.last.longitude != projectedPoint.longitude) {
      points.add(projectedPoint);
    }
    return points;
  }

  List<LatLng> _buildRemainingPoints(
    List<LatLng> route,
    int segmentIndex,
    LatLng projectedPoint,
  ) {
    if (route.isEmpty) return [];
    final points = <LatLng>[projectedPoint];
    if (segmentIndex + 1 < route.length) {
      points.addAll(route.sublist(segmentIndex + 1));
    }
    return points;
  }

  _RouteProjectionResult _projectPointOntoRoute(
    LatLng position,
    List<LatLng> route,
  ) {
    double totalMeters = 0.0;
    double bestDistance = double.infinity;
    int bestIndex = 0;
    LatLng bestPoint = route.first;
    double bestDistanceFromStart = 0.0;

    double distanceFromStart = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final segmentProjection = _projectPointOnSegment(position, start, end);
      final segmentLength = segmentProjection.segmentLengthMeters;
      if (segmentProjection.distanceMeters < bestDistance) {
        bestDistance = segmentProjection.distanceMeters;
        bestIndex = i;
        bestPoint = segmentProjection.projectedPoint;
        bestDistanceFromStart =
            distanceFromStart + (segmentProjection.t * segmentLength);
      }
      distanceFromStart += segmentLength;
    }
    totalMeters = distanceFromStart;

    return _RouteProjectionResult(
      projectedPoint: bestPoint,
      segmentIndex: bestIndex,
      distanceFromStartMeters: bestDistanceFromStart,
      distanceToRouteMeters: bestDistance,
      totalMeters: totalMeters,
    );
  }

  _SegmentProjection _projectPointOnSegment(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    final avgLat = (start.latitude + end.latitude) / 2;
    final metersPerDegLat = EarthConstants.metersPerDegreeLat;
    final metersPerDegLng = GeodesicCalculator.metersPerDegreeLng(avgLat);

    final startX = 0.0;
    final startY = 0.0;
    final endX = (end.longitude - start.longitude) * metersPerDegLng;
    final endY = (end.latitude - start.latitude) * metersPerDegLat;
    final pointX = (point.longitude - start.longitude) * metersPerDegLng;
    final pointY = (point.latitude - start.latitude) * metersPerDegLat;

    final dx = endX - startX;
    final dy = endY - startY;
    final lengthSquared = dx * dx + dy * dy;
    double t = lengthSquared == 0
        ? 0.0
        : ((pointX - startX) * dx + (pointY - startY) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);

    final projX = startX + (t * dx);
    final projY = startY + (t * dy);

    final projectedPoint = LatLng(
      start.latitude + (projY / metersPerDegLat),
      start.longitude + (projX / metersPerDegLng),
    );
    final distanceMeters = sqrt(
      pow(pointX - projX, 2) + pow(pointY - projY, 2),
    );
    final segmentLength = _calculateGeodesicDistance(start, end);

    return _SegmentProjection(
      projectedPoint: projectedPoint,
      t: t,
      distanceMeters: distanceMeters,
      segmentLengthMeters: segmentLength,
    );
  }

  double _calculateRouteDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < points.length; i++) {
      total += _calculateGeodesicDistance(points[i - 1], points[i]);
    }
    return total;
  }

  Duration? _estimateEta(double remainingMeters) {
    if (remainingMeters <= 0) return Duration.zero;
    final speedMps =
        _currentSpeed > 0.8 ? (_currentSpeed / 3.6) : _fallbackSpeedMps();
    if (speedMps <= 0) return null;
    final seconds = max(1, (remainingMeters / speedMps).round());
    return Duration(seconds: seconds);
  }

  double _fallbackSpeedMps() {
    switch (_routeTravelMode) {
      case RouteTravelMode.walk:
        return 1.4;
      case RouteTravelMode.run:
        return 2.6;
      case RouteTravelMode.bike:
        return 4.4;
    }
  }

  String _formatEta(Duration? eta) {
    if (eta == null) return '--';
    if (eta.inSeconds < 60) {
      return '${eta.inSeconds}s';
    }
    if (eta.inMinutes < 60) {
      return '${eta.inMinutes} min';
    }
    final hours = eta.inHours;
    final minutes = eta.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String _formatKm(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  bool _shouldShowRouteGuidanceCard() {
    if (!_isRealtimeRouteEnabled) return false;
    final activeRoute = _getActiveRoutePoints();
    return activeRoute.length >= 2;
  }

  Widget _buildRouteGuidanceCard() {
    final routeName = _selectedRoute?.name ?? 'Planned route';
    final hasLocation = _lastKnownLocation != null;
    final totalMeters = _routeTotalMeters > 0
        ? _routeTotalMeters
        : _calculateRouteDistanceMeters(_getActiveRoutePoints());
    final remainingMeters =
        _routeTotalMeters > 0 ? _routeRemainingMeters : totalMeters;
    final etaLabel = _formatEta(_routeEta);
    final isOffRoute =
        hasLocation && _routeDeviationMeters > _offRouteThresholdMeters;
    final statusText = !hasLocation
        ? 'Waiting for GPS'
        : isOffRoute
            ? 'Off route by ${_routeDeviationMeters.toStringAsFixed(0)} m'
            : 'On route';
    final statusColor = !hasLocation
        ? Colors.orange.shade700
        : isOffRoute
            ? Colors.redAccent
            : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route, color: Colors.blueGrey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remaining ${_formatKm(remainingMeters)} of ${_formatKm(totalMeters)} · ETA $etaLabel',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.wifi_tethering,
            size: 18,
            color: _isRealtimeRouteEnabled
                ? Colors.blueAccent
                : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  List<SavedRoute> _readRoutesCache(String key) {
    try {
      final cached = _prefs.getString(key);
      if (cached == null) return [];
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map((item) => SavedRoute.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      print('Error reading routes cache: $e');
      return [];
    }
  }

  Future<void> _writeRoutesCache(String key, List<dynamic> data) async {
    try {
      await _prefs.setString(key, jsonEncode(data));
    } catch (e) {
      print('Error saving routes cache: $e');
    }
  }

  String _popularRoutesCacheKeyForTarget(LatLng? target) {
    if (target == null) {
      return _popularRoutesCacheKeyLast;
    }
    final lat = target.latitude.toStringAsFixed(3);
    final lng = target.longitude.toStringAsFixed(3);
    return '${_popularRoutesCacheKeyPrefix}_${lat}_${lng}_5_10';
  }

  LatLng? _resolvePopularRoutesTarget() {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationTracking) {
      return LatLng(
        locationState.currentPosition.latitude,
        locationState.currentPosition.longitude,
      );
    } else if (locationState is LocationIdle &&
        locationState.lastPosition != null) {
      return LatLng(
        locationState.lastPosition!.latitude,
        locationState.lastPosition!.longitude,
      );
    }
    return null;
  }

  Future<void> _loadSavedRoutes() async {
    await _loadSavedRoutesFromCache();
    _refreshSavedRoutesFromBackend();
  }

  Future<void> _loadSavedRoutesFromCache() async {
    final cachedRoutes = _readRoutesCache(_savedRoutesCacheKey);
    if (cachedRoutes.isEmpty) {
      if (mounted) {
        setState(() => _isLoadingSavedRoutes = true);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _savedRoutes = cachedRoutes;
      _isLoadingSavedRoutes = false;
    });
    _hasCachedSavedRoutes = true;
  }

  Future<void> _refreshSavedRoutesFromBackend() async {
    if (_isRefreshingSavedRoutes) return;
    _isRefreshingSavedRoutes = true;
    try {
      final routeApi = di.getIt<RouteApiService>();
      final data = await routeApi.getMyRoutes();
      if (!mounted) return;
      setState(() {
        _savedRoutes = data.map((item) => SavedRoute.fromMap(item)).toList();
        _isLoadingSavedRoutes = false;
      });
      await _writeRoutesCache(_savedRoutesCacheKey, data);
      _hasCachedSavedRoutes = true;
    } catch (e) {
      print('Failed to load saved routes: $e');
      if (mounted && !_hasCachedSavedRoutes) {
        setState(() => _isLoadingSavedRoutes = false);
      }
    } finally {
      _isRefreshingSavedRoutes = false;
    }
  }

  Future<void> _loadPopularRoutes() async {
    final target = _resolvePopularRoutesTarget();
    await _loadPopularRoutesFromCache(target);
    _refreshPopularRoutesFromBackend(target);
  }

  Future<void> _loadPopularRoutesFromCache(LatLng? target) async {
    final key = _popularRoutesCacheKeyForTarget(target);
    var cachedRoutes = _readRoutesCache(key);
    if (cachedRoutes.isEmpty && key != _popularRoutesCacheKeyLast) {
      cachedRoutes = _readRoutesCache(_popularRoutesCacheKeyLast);
    }

    if (cachedRoutes.isEmpty) {
      if (mounted) {
        setState(() => _isLoadingPopularRoutes = true);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _popularRoutes = cachedRoutes;
      _isLoadingPopularRoutes = false;
    });
    _hasCachedPopularRoutes = true;
  }

  Future<void> _refreshPopularRoutesFromBackend(LatLng? target) async {
    if (target == null) {
      if (mounted && !_hasCachedPopularRoutes) {
        setState(() => _isLoadingPopularRoutes = false);
      }
      return;
    }
    if (_isRefreshingPopularRoutes) return;
    _isRefreshingPopularRoutes = true;
    try {
      final routeApi = di.getIt<RouteApiService>();
      final data = await routeApi.getPopularRoutes(
        lat: target.latitude,
        lng: target.longitude,
        radiusKm: 5,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _popularRoutes = data.map((item) => SavedRoute.fromMap(item)).toList();
        _isLoadingPopularRoutes = false;
      });
      final cacheKey = _popularRoutesCacheKeyForTarget(target);
      await _writeRoutesCache(cacheKey, data);
      await _writeRoutesCache(_popularRoutesCacheKeyLast, data);
      _hasCachedPopularRoutes = true;
    } catch (e) {
      print('Failed to load popular routes: $e');
      if (mounted && !_hasCachedPopularRoutes) {
        setState(() => _isLoadingPopularRoutes = false);
      }
    } finally {
      _isRefreshingPopularRoutes = false;
    }
  }

  Future<void> _openRoutesSheet() async {
    await _loadSavedRoutes();
    await _loadPopularRoutes();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Routes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      if (_selectedRoute != null)
                        Text(
                          'Selected: ${_selectedRoute!.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                TabBar(
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.grey.shade500,
                  tabs: const [
                    Tab(text: 'Create'),
                    Tab(text: 'Saved'),
                    Tab(text: 'Popular'),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 380,
                  child: TabBarView(
                    children: [
                      _buildCreateRouteTab(),
                      _buildSavedRoutesTab(),
                      _buildPopularRoutesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateRouteTab() {
    final distanceKm = _plannedRoutePoints.length < 2
        ? 0.0
        : _calculatePlannedRouteDistanceKm();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isPlanningRoute
                ? 'Tap on the map to add points'
                : 'Start planning by enabling route draw',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isPlanningRoute = !_isPlanningRoute;
                      if (_isPlanningRoute) {
                        _selectedRoute = null;
                      }
                    });
                    _refreshRoutePreviewFromLocation(
                      _lastKnownLocation,
                      force: true,
                    );
                  },
                  icon: Icon(_isPlanningRoute ? Icons.close : Icons.edit_road),
                  label: Text(
                    _isPlanningRoute ? 'Stop Planning' : 'Plan Route',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isPlanningRoute ? Colors.red.shade400 : Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Distance: ${distanceKm.toStringAsFixed(2)} km',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Text(
                '${_plannedRoutePoints.length} pts',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.wifi_tethering,
                      size: 16,
                      color: Colors.blueGrey.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Realtime guidance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Spacer(),
                    Switch(
                      value: _isRealtimeRouteEnabled,
                      activeColor: Colors.blueGrey.shade800,
                      onChanged: (value) {
                        setState(() => _isRealtimeRouteEnabled = value);
                        _refreshRoutePreviewFromLocation(
                          _lastKnownLocation,
                          force: true,
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Travel mode',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: RouteTravelMode.values.map((mode) {
                    final isSelected = _routeTravelMode == mode;
                    final label = mode == RouteTravelMode.walk
                        ? 'Walk'
                        : mode == RouteTravelMode.run
                            ? 'Run'
                            : 'Bike';
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: Colors.blueGrey.shade200,
                      onSelected: (_) {
                        setState(() => _routeTravelMode = mode);
                        _refreshRoutePreviewFromLocation(
                          _lastKnownLocation,
                          force: true,
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isPlanningRoute ? _addCurrentLocationToPlan : null,
                  icon: Icon(Icons.my_location, size: 18),
                  label: Text('Add My Location'),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _plannedRoutePoints.isEmpty
                      ? null
                      : _undoPlannedRoutePoint,
                  child: Text('Undo'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _plannedRoutePoints.isEmpty ? null : _clearPlannedRoute,
                  child: Text('Clear'),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed:
                _plannedRoutePoints.length < 2 ? null : _savePlannedRoute,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 44),
              backgroundColor: Colors.blueGrey.shade800,
              foregroundColor: Colors.white,
            ),
            child: Text('Save Route'),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRoutesTab() {
    if (_isLoadingSavedRoutes) {
      return _buildRouteListSkeleton();
    }
    if (_savedRoutes.isEmpty) {
      return Center(
        child: Text(
          'No saved routes yet',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _savedRoutes.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final route = _savedRoutes[index];
        return ListTile(
          title: Text(route.name),
          subtitle: Text('${route.distanceKm.toStringAsFixed(2)} km'),
          trailing: Icon(Icons.chevron_right),
          onTap: () {
            _previewRoute(route);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildPopularRoutesTab() {
    if (_isLoadingPopularRoutes) {
      return _buildRouteListSkeleton();
    }
    if (_popularRoutes.isEmpty) {
      return Center(
        child: Text(
          'No popular routes nearby',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _popularRoutes.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final route = _popularRoutes[index];
        return ListTile(
          title: Text(route.name),
          subtitle: Text(
            '${route.distanceKm.toStringAsFixed(2)} km • ${route.usageCount} uses',
          ),
          trailing: Icon(Icons.chevron_right),
          onTap: () {
            _previewRoute(route);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildRouteListSkeleton() {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            SkeletonBox(height: 56, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  double _calculatePlannedRouteDistanceKm() {
    if (_plannedRoutePoints.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _plannedRoutePoints.length; i++) {
      total += _calculateGeodesicDistance(
        _plannedRoutePoints[i - 1],
        _plannedRoutePoints[i],
      );
    }
    return total / 1000;
  }

  Future<void> _savePlannedRoute() async {
    final controller = TextEditingController();
    bool isPublic = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Save Route'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(labelText: 'Route name'),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isPublic,
                        onChanged: (value) {
                          setStateDialog(() {
                            isPublic = value ?? false;
                          });
                        },
                      ),
                      Text('Make public'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final name = controller.text.trim();
    if (name.isEmpty) return;

    try {
      final routeApi = di.getIt<RouteApiService>();
      await routeApi.createRoute(
        name: name,
        isPublic: isPublic,
        routePoints: _plannedRoutePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Route saved')));
      setState(() {
        _isPlanningRoute = false;
        _plannedRoutePoints.clear();
        _plannedRoutePreviewPoints.clear();
      });
      _refreshRoutePreviewFromLocation(_lastKnownLocation, force: true);
      await _loadSavedRoutes();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save route')));
    }
  }

  Future<void> _recordSelectedRouteUsage() async {
    if (_selectedRoute == null) return;
    try {
      final routeApi = di.getIt<RouteApiService>();
      await routeApi.recordRouteUsage(_selectedRoute!.id);
    } catch (e) {
      print('⚠️ Failed to record route usage: $e');
    }
  }

  Future<void> _loadBossTerritoriesFromBackend() async {
    try {
      final territoryApiService = di.getIt<TerritoryApiService>();
      final authService = di.getIt<AuthApiService>();
      final currentUserId = await authService.getUserId() ?? '';

      final cached = await _territoryCacheDataSource.getBossTerritories();
      if (cached.isNotEmpty && mounted) {
        print('Using cached boss territories (${cached.length})');
        _renderBossTerritories(cached, currentUserId);
      }

      try {
        final bosses = await territoryApiService.getBossTerritories(limit: 3);
        await _territoryCacheDataSource.saveBossTerritories(bosses);
        if (mounted) {
          _renderBossTerritories(bosses, currentUserId);
        }
      } catch (e) {
        print('Failed to load boss territories from backend: $e');
        if (cached.isEmpty) {
          print('No cached boss territories available');
        }
      }
    } catch (e) {
      print('Failed to load boss territories: $e');
    }
  }

  void _renderBossTerritories(
    List<Map<String, dynamic>> bosses,
    String currentUserId,
  ) {
    if (!mounted) return;

    final pendingBossMarkers = <Map<String, dynamic>>[];
    setState(() {
      _polygons.removeWhere(
        (polygon) => polygon.polygonId.value.startsWith('boss_'),
      );
      _territoryMarkers.removeWhere(
        (marker) => marker.markerId.value.startsWith('boss_'),
      );

      for (final boss in bosses) {
        final hexId = boss['hexId'];
        final lat = boss['latitude'] is String
            ? double.parse(boss['latitude'])
            : (boss['latitude'] as num).toDouble();
        final lng = boss['longitude'] is String
            ? double.parse(boss['longitude'])
            : (boss['longitude'] as num).toDouble();

        final ownerId = boss['ownerId'];
        final bool isOwnTerritory = ownerId == currentUserId;
        final bossColor = Colors.amber;

        final routePoints = boss['routePoints'] as List?;
        List<LatLng>? polygonPoints;

        if (routePoints != null && routePoints.isNotEmpty) {
          final parsedPoints = routePoints.map((p) {
            final pointLat = p['lat'] is String
                ? double.parse(p['lat'])
                : (p['lat'] as num).toDouble();
            final pointLng = p['lng'] is String
                ? double.parse(p['lng'])
                : (p['lng'] as num).toDouble();
            return LatLng(pointLat, pointLng);
          }).toList();
          if (parsedPoints.length >= 3) {
            polygonPoints = parsedPoints;
          }
        }

        if (polygonPoints == null) {
          polygonPoints = _generateCirclePoints(LatLng(lat, lng), 25);
        }

        _polygons.add(
          Polygon(
            polygonId: PolygonId('boss_$hexId'),
            points: polygonPoints,
            fillColor: bossColor.withOpacity(_territoryFillOpacity),
            strokeColor: bossColor.withOpacity(0.7),
            strokeWidth: 3,
          ),
        );

        final ownerName = boss['owner']?['name'] ?? 'Unknown';
        final bossCaptureCount = _toIntSafe(boss['captureCount'], fallback: 1);
        final bossPoints = boss['points'];
        final bossCapturedAt = boss['capturedAt'] != null
            ? DateTime.parse(boss['capturedAt'])
            : null;
        final bossLastBattleAt = boss['lastBattleAt'] != null
            ? DateTime.parse(boss['lastBattleAt'])
            : null;
        final bossAreaSqMeters = _calculatePolygonArea(polygonPoints);
        final ownerData = boss['owner'];
        final ownerAvatarSource =
            _extractAvatarFromMap(ownerData) ?? _extractAvatarFromMap(boss);

        final bossOnTap = () {
          _showTerritoryInfo(
            ownerName: ownerName,
            captureCount: bossCaptureCount,
            isOwn: isOwnTerritory,
            points: bossPoints,
            capturedAt: bossCapturedAt,
            lastBattleAt: bossLastBattleAt,
            areaSqMeters: bossAreaSqMeters,
            isBoss: true,
            bossRewardPoints: boss['bossRewardPoints'],
            avatarSource: ownerAvatarSource,
            territoryId: boss['id']?.toString(),
          );
        };

        _territoryMarkers.add(
          Marker(
            markerId: MarkerId('boss_$hexId'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            onTap: bossOnTap,
          ),
        );

        final markerId = 'boss_$hexId';
        final markerPosition = LatLng(lat, lng);
        pendingBossMarkers.add({
          'markerId': markerId,
          'position': markerPosition,
          'territoryId': boss['id']?.toString(),
          'ownerId': ownerId,
          'ownerName': ownerName,
          'captureCount': bossCaptureCount,
          'points': bossPoints,
          'capturedAt': bossCapturedAt,
          'lastBattleAt': bossLastBattleAt,
          'areaSqMeters': bossAreaSqMeters,
          'bossRewardPoints': boss['bossRewardPoints'],
          'avatarSource': ownerAvatarSource,
        });

        _territoryData[hexId] = {
          'polygonPoints': polygonPoints,
          'territoryId': boss['id']?.toString(),
          'ownerId': ownerId,
          'ownerName': boss['owner']?['name'] ?? 'Unknown',
          'captureCount': boss['captureCount'] ?? 1,
          'isOwn': isOwnTerritory,
          'points': boss['points'],
          'capturedAt': boss['capturedAt'] != null
              ? DateTime.parse(boss['capturedAt'])
              : null,
          'lastBattleAt': boss['lastBattleAt'] != null
              ? DateTime.parse(boss['lastBattleAt'])
              : null,
          'areaSqMeters': bossAreaSqMeters,
          'isBoss': true,
          'bossRewardPoints': boss['bossRewardPoints'],
        };
      }
    });

    for (final pending in pendingBossMarkers) {
      final markerId = pending['markerId'] as String;
      final position = pending['position'] as LatLng;
      final ownerId = pending['ownerId']?.toString();
      final ownerName = pending['ownerName']?.toString() ?? 'Unknown';
      final captureCount = _toIntSafe(pending['captureCount'], fallback: 1);
      final pointsRaw = pending['points'];
      final points = pointsRaw == null ? null : _toIntSafe(pointsRaw);
      final capturedAt = pending['capturedAt'] as DateTime?;
      final lastBattleAt = pending['lastBattleAt'] as DateTime?;
      final areaSqMeters = _toDoubleSafe(pending['areaSqMeters']);
      final bossRewardRaw = pending['bossRewardPoints'];
      final bossRewardPoints =
          bossRewardRaw == null ? null : _toIntSafe(bossRewardRaw);
      final baseAvatarSource = pending['avatarSource']?.toString();

      void showSheet(String? avatar) {
        _showTerritoryInfo(
          ownerName: ownerName,
          captureCount: captureCount,
          isOwn: ownerId == _currentUserIdFromAuth(),
          points: points,
          capturedAt: capturedAt,
          lastBattleAt: lastBattleAt,
          areaSqMeters: areaSqMeters,
          isBoss: true,
          bossRewardPoints: bossRewardPoints,
          avatarSource: avatar,
          territoryId: pending['territoryId']?.toString(),
        );
      }

      if (baseAvatarSource != null && baseAvatarSource.isNotEmpty) {
        _scheduleCapturedAreaAvatarUpdate(
          markerId: markerId,
          position: position,
          avatarCacheKey: ownerId ?? markerId,
          avatarSource: baseAvatarSource,
          onTap: () => showSheet(baseAvatarSource),
        );
      }

      if (ownerId != null && ownerId.isNotEmpty) {
        _ensureUserProfile(ownerId).then((profile) {
          final resolvedAvatar = _extractAvatarFromMap(profile) ??
              (ownerId == _currentUserIdFromAuth()
                  ? _currentUserAvatarSource()
                  : null);
          if (resolvedAvatar == null || resolvedAvatar.isEmpty) return;
          _scheduleCapturedAreaAvatarUpdate(
            markerId: markerId,
            position: position,
            avatarCacheKey: ownerId,
            avatarSource: resolvedAvatar,
            onTap: () => showSheet(resolvedAvatar),
          );
        });
      }
    }
  }

  void _emitMyLocationUpdate() {
    if (_currentUserId == null) return;
    final locationState = context.read<LocationBloc>().state;
    if (locationState is! LocationTracking) return;
    _webSocketService.emitLocationUpdate(
      userId: _currentUserId!,
      lat: locationState.currentPosition.latitude,
      lng: locationState.currentPosition.longitude,
      speed: _currentSpeed,
    );
  }

  Future<void> _handleUserLocation(dynamic payload) async {
    if (!mounted) return;
    if (payload is! Map) return;
    final userId = payload['userId']?.toString();
    if (userId == null || userId == _currentUserId) return;
    final lat = payload['lat'];
    final lng = payload['lng'];
    if (lat is! num || lng is! num) return;

    _userLastSeen[userId] = DateTime.now();
    final position = LatLng(lat.toDouble(), lng.toDouble());
    final profile = await _ensureUserProfile(userId);
    final marker = await _buildUserMarker(userId, position, profile);
    if (marker == null || !mounted) return;

    setState(() {
      _userMarkersById[userId] = marker;
    });
  }

  void _handleTerritoryCaptured(dynamic payload) {
    if (!mounted) return;

    String? eventId;
    int? eventTs;
    dynamic rawTerritories = payload;

    if (payload is Map) {
      if (payload['territories'] is List) {
        rawTerritories = payload['territories'];
      }
      eventId = payload['eventId']?.toString();
      final tsRaw = payload['ts'];
      if (tsRaw is num) {
        eventTs = tsRaw.toInt();
      } else if (tsRaw != null) {
        eventTs = int.tryParse(tsRaw.toString());
      }
    }

    final List<Map<String, dynamic>> territories = [];
    if (rawTerritories is List) {
      for (final item in rawTerritories) {
        if (item is Map) {
          territories.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (rawTerritories is Map) {
      territories.add(Map<String, dynamic>.from(rawTerritories));
    }

    if (territories.isEmpty) return;
    final currentUserId = _currentUserIdFromAuth() ?? _currentUserId ?? '';
    _renderTerritories(territories, currentUserId);

    if (eventId != null && eventTs != null) {
      _webSocketService.emitTerritoryAck(eventId: eventId, ts: eventTs);
    }
  }

  Future<void> _handleTerritorySnapshot(dynamic payload) async {
    if (!mounted) return;

    dynamic rawTerritories = payload;
    if (payload is Map && payload['territories'] is List) {
      rawTerritories = payload['territories'];
    }

    final List<Map<String, dynamic>> territories = [];
    if (rawTerritories is List) {
      for (final item in rawTerritories) {
        if (item is Map) {
          territories.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (rawTerritories is Map) {
      territories.add(Map<String, dynamic>.from(rawTerritories));
    }

    if (territories.isEmpty) return;
    final currentUserId = _currentUserIdFromAuth() ?? _currentUserId ?? '';
    _renderTerritories(territories, currentUserId);
    await _mergeAndCacheNearby(territories);
  }

  Future<void> _mergeAndCacheNearby(
    List<Map<String, dynamic>> territories,
  ) async {
    if (territories.isEmpty) return;
    try {
      final cached = await _territoryCacheDataSource.getNearbyTerritories();
      final merged = <String, Map<String, dynamic>>{};
      for (final territory in cached) {
        final hexId = territory['hexId']?.toString();
        if (hexId != null && hexId.isNotEmpty) {
          merged[hexId] = territory;
        }
      }
      for (final territory in territories) {
        final hexId = territory['hexId']?.toString();
        if (hexId != null && hexId.isNotEmpty) {
          merged[hexId] = territory;
        }
      }
      await _territoryCacheDataSource.saveNearbyTerritories(
        merged.values.toList(),
      );
    } catch (e) {
      print('Failed to merge nearby territories: $e');
    }
  }

  Future<Map<String, dynamic>?> _ensureUserProfile(String userId) async {
    final cached = _userProfileCache[userId];
    if (cached != null) return cached;
    if (_profileFetchInFlight.contains(userId)) return null;
    _profileFetchInFlight.add(userId);
    try {
      final profile = await _userProfileApiService.getPublicProfile(userId);
      _userProfileCache[userId] = profile;
      return profile;
    } catch (e) {
      print('Failed to load user profile: $e');
      return null;
    } finally {
      _profileFetchInFlight.remove(userId);
    }
  }

  Future<Marker?> _buildUserMarker(
    String userId,
    LatLng position,
    Map<String, dynamic>? profile,
  ) async {
    final name = profile?['name']?.toString() ?? 'Runner';
    final avatarUrl = profile?['avatarImageUrl']?.toString() ??
        profile?['avatarModelUrl']?.toString() ??
        profile?['profilePicture']?.toString();
    BitmapDescriptor? icon;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      icon = await _getAvatarMarkerIcon(userId, avatarUrl);
    }

    return Marker(
      markerId: MarkerId('user_$userId'),
      position: position,
      icon: icon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(title: name),
      zIndex: 20.0,
    );
  }

  Future<void> _updateCurrentUserMarker(LatLng position) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    final user = authState.user;
    final avatarSource = user.avatarImageUrl ?? user.avatarModelUrl ?? '';

    BitmapDescriptor? icon;
    if (avatarSource.isNotEmpty) {
      icon = await _getAvatarMarkerIcon(
        user.id,
        avatarSource,
        ringColor: _markerRingColor,
      );
    }
    if (!mounted) return;

    setState(() {
      _currentUserMarker = Marker(
        markerId: const MarkerId('current_user'),
        position: position,
        icon: icon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: icon != null ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
        infoWindow: const InfoWindow(title: 'You'),
        zIndex: 30.0,
      );
    });
  }

  Future<BitmapDescriptor?> _getAvatarMarkerIcon(
    String userId,
    String avatarUrl, {
    Color? ringColor,
  }) async {
    final resolvedUrl = _resolveAvatarImageUrl(avatarUrl);
    final cacheKey = '$resolvedUrl|${ringColor?.value ?? 0}';
    final cached = _userAvatarIconCache[userId];
    if (cached != null && _userAvatarUrlCache[userId] == cacheKey) {
      return cached;
    }
    try {
      final bytes = await _loadAvatarBytes(resolvedUrl);
      if (bytes == null) return null;
      final icon = await _createCircularAvatarMarker(
        bytes,
        ringColor: ringColor,
      );
      _userAvatarIconCache[userId] = icon;
      _userAvatarUrlCache[userId] = cacheKey;
      return icon;
    } catch (e) {
      print('Failed to load avatar icon: $e');
      return null;
    }
  }

  String _resolveAvatarImageUrl(String avatarUrl) {
    return AvatarPresetService.resolveAvatarImageUrl(avatarUrl);
  }

  Future<Uint8List?> _loadAvatarBytes(String avatarUrl) async {
    if (AvatarPresetService.isAssetPath(avatarUrl)) {
      final assetPath = AvatarPresetService.normalizeAssetPath(avatarUrl);
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    }
    final uri = Uri.tryParse(avatarUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return null;
    }
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  }

  Future<BitmapDescriptor> _createCircularAvatarMarker(
    Uint8List bytes, {
    int size = 96,
    Color? ringColor,
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = Paint();
    final rect = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final radius = size / 2.0;
    final clipPath = ui.Path()..addOval(rect);

    canvas.clipPath(clipPath);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );

    final borderPaint = Paint()
      ..color = ringColor ?? Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(ui.Offset(radius, radius), radius - 2, borderPaint);

    final picture = recorder.endRecording();
    final roundedImage = await picture.toImage(size, size);
    final byteData = await roundedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  void _pruneStaleUsers() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 90));
    final staleIds = _userLastSeen.entries
        .where((entry) => entry.value.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList();
    if (staleIds.isEmpty) return;
    setState(() {
      for (final userId in staleIds) {
        _userMarkersById.remove(userId);
        _userLastSeen.remove(userId);
      }
    });
  }

  void _handleBoostUpdate(dynamic payload) {
    if (payload == null) return;
    try {
      final map = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      final boostRaw = map['boost'] ?? map;
      if (boostRaw == null || boostRaw.isEmpty) {
        _mapDropService.applyBoostFromServer(null);
        if (mounted) {
          setState(() {
            _activeDropBoost = null;
          });
        } else {
          _activeDropBoost = null;
        }
        return;
      }
      final boost = MapDropBoost.fromJson(Map<String, dynamic>.from(boostRaw));
      _mapDropService.applyBoostFromServer(boost);
      if (mounted) {
        setState(() {
          _activeDropBoost = boost;
        });
      } else {
        _activeDropBoost = boost;
      }
      _syncBoostTicker();
    } catch (e) {
      print('[boost] update failed: $e');
    }
  }

  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
    if (_showHeatmap) {
      _buildHeatmapCircles();
    }
  }

  void _buildHeatmapCircles() {
    if (_activityHistory.isEmpty) {
      _heatmapCircles.clear();
      return;
    }

    const double gridSize = 0.0005; // ~55m
    const int maxCircles = 200;
    final Map<String, _HeatCell> cells = {};
    final now = DateTime.now();

    for (final activity in _activityHistory) {
      final routePoints = activity['routePoints'] as List<dynamic>?;
      if (routePoints == null || routePoints.isEmpty) continue;
      final activityTime = _parseDateTimeSafe(
        activity['startTime'] ?? activity['endTime'] ?? activity['createdAt'],
      );
      final daysAgo = activityTime != null
          ? now.difference(activityTime).inDays.clamp(0, 365)
          : 30;
      final recencyWeight = (1 / (1 + daysAgo / 10)).clamp(0.2, 1.0);

      for (int i = 0; i < routePoints.length; i += 5) {
        final parsed = _parseRoutePoint(routePoints[i]);
        if (parsed == null) continue;
        final lat = parsed.latitude;
        final lng = parsed.longitude;
        final key = '${(lat / gridSize).round()}:${(lng / gridSize).round()}';
        final cell = cells.putIfAbsent(key, () => _HeatCell());
        cell.count += recencyWeight;
        cell.sumLat += lat * recencyWeight;
        cell.sumLng += lng * recencyWeight;
      }
    }

    final entries = cells.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    _heatmapCircles.clear();
    for (final cell in entries.take(maxCircles)) {
      final lat = cell.sumLat / cell.count;
      final lng = cell.sumLng / cell.count;
      final intensity = (cell.count / 8).clamp(0.15, 0.75);
      final radius = 24 + (cell.count * 6).clamp(0, 80);
      _heatmapCircles.add(
        Circle(
          circleId: CircleId(
            'heat_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
          ),
          center: LatLng(lat, lng),
          radius: radius.toDouble(),
          fillColor: Colors.red.withOpacity(intensity),
          strokeColor: Colors.red.withOpacity(intensity + 0.1),
          strokeWidth: 1,
        ),
      );
    }
  }

  void _updateLocalStreaks() {
    if (_activityHistory.isEmpty) {
      _localStreakDays = 0;
      _bestStreakDays = 0;
      return;
    }

    final dates = <DateTime>{};
    for (final activity in _activityHistory) {
      final time = _parseDateTimeSafe(
        activity['startTime'] ?? activity['endTime'] ?? activity['createdAt'],
      );
      if (time == null) continue;
      dates.add(DateTime(time.year, time.month, time.day));
    }

    if (dates.isEmpty) {
      _localStreakDays = 0;
      _bestStreakDays = 0;
      return;
    }

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!dates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int currentStreak = 0;
    while (dates.contains(cursor)) {
      currentStreak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final sorted = dates.toList()..sort();
    int bestStreak = 1;
    int streak = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        streak += 1;
      } else if (diff > 1) {
        if (streak > bestStreak) bestStreak = streak;
        streak = 1;
      }
    }
    if (streak > bestStreak) bestStreak = streak;

    _localStreakDays = currentStreak;
    _bestStreakDays = bestStreak;
  }

  Set<Circle> _getMapCircles() {
    final circles = <Circle>{};
    if (_trackingState == TrackingState.started && _startPointCircle != null) {
      circles.add(_startPointCircle!);
    }
    if (_showHeatmap) {
      circles.addAll(_heatmapCircles);
    }
    circles.addAll(_dropCircles);
    circles.addAll(_poiCircles);
    return circles;
  }

  Widget _buildDropBoostChip() {
    final boost = _activeDropBoost ?? _mapDropService.activeBoost;
    if (boost == null || !boost.isActive) {
      return const SizedBox.shrink();
    }
    final remaining = boost.remaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final label = 'Boost 2x ${minutes}:${seconds.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: _showDropInfoSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionChip() {
    final mission = _activePoiMission;
    if (mission == null || mission.pois.isEmpty) {
      return const SizedBox.shrink();
    }
    final label =
        'Mission ${mission.visited.length}/${mission.pois.length}';

    return GestureDetector(
      onTap: _openPoiMissionSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip() {
    final badge = _rewardsShopService.selectedBadgeItem;
    if (badge == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _openRewardsShop,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: badge.color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge.icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              badge.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
              print(
                "${value ? '🎮' : '📍'} Simulation mode: ${value ? 'ON' : 'OFF'}",
              );
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
    final currentDistanceKm = locationState is LocationTracking
        ? locationState.totalDistance / 1000
        : 0.0;

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
                Icon(Icons.crop_square, size: 12, color: Colors.purple),
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
          if (_goalDistanceKm != null || _goalAreaSqMeters != null) ...[
            SizedBox(height: 6),
            Divider(height: 1),
            SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag, size: 12, color: Colors.blueGrey),
                SizedBox(width: 4),
                Text(
                  _goalDistanceKm != null
                      ? 'Goal: ${(currentDistanceKm / _goalDistanceKm! * 100).clamp(0, 100).toStringAsFixed(0)}%'
                      : _estimatedAreaSqMeters > 0
                          ? 'Goal: ${(_estimatedAreaSqMeters / _goalAreaSqMeters! * 100).clamp(0, 100).toStringAsFixed(0)}%'
                          : 'Goal set',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
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

      if (locationState is LocationTracking &&
          locationState.routePoints.isNotEmpty) {
        final lastPoint = locationState.routePoints.last;
        currentPosition = LatLng(lastPoint.latitude, lastPoint.longitude);
      } else if (locationState is LocationIdle &&
          locationState.lastPosition != null) {
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

  // Show activity route on map
  void _showActivityOnMap(Map<String, dynamic> activity) {
    if (_mapController == null) return;

    // Get route points from activity
    final routePoints = activity['routePoints'] as List<dynamic>?;
    if (routePoints == null || routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No route data available for this activity')),
      );
      return;
    }

    // Convert route points to LatLng
    final List<LatLng> latLngPoints =
        routePoints.map(_parseRoutePoint).whereType<LatLng>().toList();
    if (latLngPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough route points to show activity')),
      );
      return;
    }

    // Clear existing polylines and add the activity route
    setState(() {
      _polylines.clear();
      _activityData.clear();

      // Store activity data
      _activityData['activity_route'] = activity;

      _polylines.add(
        Polyline(
          polylineId: PolylineId('activity_route'),
          points: latLngPoints,
          color: Color(0xFF2196F3), // Brighter blue
          width: 10,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          consumeTapEvents: true,
          onTap: () {
            print('🔵 Activity route polyline tapped');
            _handlePolylineTap(PolylineId('activity_route'));
          },
        ),
      );
    });

    // Calculate bounds to fit all points
    double minLat = latLngPoints.first.latitude;
    double maxLat = latLngPoints.first.latitude;
    double minLng = latLngPoints.first.longitude;
    double maxLng = latLngPoints.first.longitude;

    for (var point in latLngPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add padding to bounds
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    // Animate camera to show the entire route
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// HANDLE POLYLINE TAP - Show Activity Details
  /// ═══════════════════════════════════════════════════════════════════════════
  void _handlePolylineTap(PolylineId polylineId) {
    print('🎯 _handlePolylineTap called with: ${polylineId.value}');
    final activity = _activityData[polylineId.value];
    print('📦 Activity data found: ${activity != null}');
    if (activity != null) {
      print('🎭 Showing bottom drawer...');
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => ActivityDetailDrawer(activity: activity),
      );
    } else {
      print('❌ No activity data found for ${polylineId.value}');
      print('   Available keys: ${_activityData.keys.toList()}');
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// HANDLE MAP TAP - Check if inside activity area and show drawer
  /// ═══════════════════════════════════════════════════════════════════════════
  void _handleMapTapForActivities(LatLng tapPosition) {
    print(
      '🗺️ Map tapped at: ${tapPosition.latitude}, ${tapPosition.longitude}',
    );
    print('📊 Total activity data entries: ${_activityData.length}');
    print('�️ Total territory data entries: ${_territoryData.length}');

    // First check activity polygons (user's own completed loops)
    for (final entry in _activityData.entries) {
      if (entry.key.startsWith('saved_area_')) {
        final activity = entry.value;
        final routeData = activity['routePoints'] as List<dynamic>?;

        if (routeData != null && routeData.length >= 3) {
          final routePoints = routeData
              .map(
                (p) =>
                    LatLng(p['latitude'] as double, p['longitude'] as double),
              )
              .toList();

          if (_isPointInPolygon(tapPosition, routePoints)) {
            print('✅ Tap is inside activity polygon: ${entry.key}');
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => ActivityDetailDrawer(activity: activity),
            );
            return;
          }
        }
      }
    }

    // Then check territory polygons (all territories including others')
    for (final entry in _territoryData.entries) {
      final hexId = entry.key;
      final data = entry.value;
      final polygonPoints = data['polygonPoints'] as List<LatLng>;

      if (_isPointInPolygon(tapPosition, polygonPoints)) {
        print('✅ Tap is inside territory: $hexId');
        print('   Owner: ${data['ownerName']}');

        // Show territory owner info drawer
        _showTerritoryOwnerDrawer(
          ownerName: data['ownerName'],
          isOwn: data['isOwn'],
          captureCount: data['captureCount'],
          territoryId: data['territoryId']?.toString(),
        );
        return;
      }
    }

    print('❌ Tap not inside any activity or territory area');
  }

  /// Show territory owner info in bottom drawer
  void _showTerritoryOwnerDrawer({
    required String ownerName,
    required bool isOwn,
    required int captureCount,
    String? territoryId,
  }) {
    _showTerritoryInfo(
      ownerName: ownerName,
      captureCount: captureCount,
      isOwn: isOwn,
      territoryId: territoryId,
    );
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
    final recentPoints = state.routePoints.sublist(
      state.routePoints.length - numPoints,
    );

    if (recentPoints.length < 2) return;

    // Calculate segment speeds with weights (more recent = higher weight)
    final segmentSpeeds = <double>[];
    final weights = <double>[];

    for (int i = 1; i < recentPoints.length; i++) {
      final p1 = recentPoints[i - 1];
      final p2 = recentPoints[i];

      final distance = geo.Geolocator.distanceBetween(
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );

      final timeDiff =
          p2.timestamp.difference(p1.timestamp).inMilliseconds / 1000.0;

      if (timeDiff > 0 && timeDiff < 30) {
        // Reject segments with invalid time
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

  // Animated control buttons (Start -> Pause/End + Home + History)
  Widget _buildControlButtons(bool isTracking) {
    return AnimatedBuilder(
      animation: _buttonAnimController,
      builder: (context, child) {
        final isExpanded = _trackingState == TrackingState.started ||
            _trackingState == TrackingState.paused;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Home button (only visible when not tracking)
            if (!isExpanded) ...[
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
            ],

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
                        color: _trackingState == TrackingState.paused
                            ? Colors.green
                            : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_trackingState == TrackingState.paused
                                    ? Colors.green
                                    : Colors.orange)
                                .withOpacity(0.3),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _trackingState == TrackingState.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
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
                  _useSimulation = false;
                  _handleStart(context);
                }
              },
              onLongPressStart: (_) {
                if (_trackingState == TrackingState.stopped) {
                  _showTrackingModeSelector(context);
                  return;
                }
                _startHoldTimer(context);
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
                      color: _trackingState == TrackingState.stopped
                          ? Colors.black87
                          : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_trackingState == TrackingState.stopped
                                  ? Colors.black87
                                  : Colors.red)
                              .withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _trackingState == TrackingState.stopped
                          ? Icons.play_arrow_rounded
                          : Icons.stop_rounded,
                      size: 35,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // History button (only visible when not tracking)
            if (!isExpanded) ...[
              SizedBox(width: 20),
              GestureDetector(
                onTap: () async {
                  final selectedActivity =
                      await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ActivityHistorySheet(),
                  );

                  if (selectedActivity != null) {
                    _showActivityOnMap(selectedActivity);
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
                  child: Icon(Icons.history, size: 28, color: Colors.black87),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _startHoldTimer(BuildContext context) {
    if (_isEndingSession || _showEndAnimation) return;
    if (_trackingState == TrackingState.stopped) return;
    _holdTimer?.cancel();
    setState(() {
      _isHoldingEnd = true;
      _holdProgress = 0.0;
    });

    const updateInterval = Duration(milliseconds: 50);
    final totalSteps =
        _holdDuration.inMilliseconds / updateInterval.inMilliseconds;
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
    _holdTimer = null;
    setState(() {
      _isHoldingEnd = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _refreshSyncStatus() async {
    try {
      final pending = await _pendingSyncDataSource.getPending();
      if (!mounted) return;
      setState(() {
        _pendingSyncCount = pending.length;
      });
    } catch (e) {
      print('[warn] Sync status refresh failed: $e');
    }
  }

  void _disableFollowOnGesture() {
    if (_trackingState != TrackingState.started) return;
    if (!_followUser) return;
    if (!mounted) {
      _followUser = false;
      return;
    }
    setState(() {
      _followUser = false;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length >= 2) {
      _disableFollowOnGesture();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _triggerBackgroundSync() {
    if (_isSyncing) return;
    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    } else {
      _isSyncing = true;
    }

    _offlineSyncService
        .syncPending()
        .then((synced) async {
          await _refreshSyncStatus();
          if (synced > 0) {
            await _loadSavedCapturedAreas();
            if (_lastKnownLocation != null) {
              _scheduleTerritoryFetch(_lastKnownLocation!, force: true);
            } else {
              await _refreshRecentTerritories();
            }
          }
        })
        .whenComplete(() {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      } else {
        _isSyncing = false;
      }
    });
  }

  void _handleStart(BuildContext context) {
    if (_showLocationGate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable precise location to start tracking.'),
        ),
      );
      _checkPreciseLocationAccess(requestPermission: true);
      return;
    }
    setState(() {
      _currentLoopId = _uuid.v4();
      _trackingState = TrackingState.started;
      _followUser = true;
      // Prevent stale start marker from previous sessions.
      _startPointCircle = null;
      _loopStartIndex = 0;
      _loopStartDistanceMeters = 0.0;
      _loopCaptureInFlight = false;
      _lastLoopCaptureAt = null;
      _reportedHexIds.clear();
      _capturedHexIds.clear();
      _smoothedCameraTarget = null;
      _smoothedCameraBearing = null;
      _splitIndex = 0;
      _nextSplitAtMeters = _splitDistanceMeters;
      _lastSplitTime = null;
      _lastSplitPace = null;
      _lastSplitDuration = null;
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
      context.read<LocationBloc>().add(
            StartLocationTracking(
              useSimulation: _useSimulation,
              batterySaver: _batterySaverEnabled,
            ),
          );
      _motionDetection.startDetection();

      final locationState = context.read<LocationBloc>().state;
      final distance = locationState is LocationTracking
          ? locationState.totalDistance / 1000
          : 0.0;
      final territoriesState = context.read<TerritoryBloc>().state;
      final territoriesCount = territoriesState is TerritoryLoaded
          ? territoriesState.territories.length
          : 0;

      BackgroundTrackingService.startTracking(
        currentDistance: distance,
        territoriesCount: territoriesCount,
      );

      print('▶️ TRACKING RESUMED');
    }
  }

  void _handleEnd(BuildContext context) {
    if (_isEndingSession || _showEndAnimation) return;
    if (_trackingState == TrackingState.stopped) return;
    print('🛑 _handleEnd called - Starting end countdown');
    _isEndingSession = true;
    _holdTimer?.cancel();
    _holdTimer = null;
    // Start end countdown animation
    setState(() {
      _showEndAnimation = true;
      _endCountdown = 3;
    });

    _endTimer?.cancel();
    _endTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endCountdown > 0) {
        // Audio removed - file not available
        setState(() => _endCountdown--);
        print('⏱️ End countdown: $_endCountdown');
      } else {
        timer.cancel();
        _endTimer = null;
        setState(() => _showEndAnimation = false);
        print('✅ End countdown complete - calling _completeEndSession');
        _completeEndSession(context);
      }
    });
  }

  Future<void> _completeEndSession(BuildContext context) async {
    print('🏁 _completeEndSession START');
    try {
      // CRITICAL: Capture location state BEFORE stopping tracking!
      final locationState = context.read<LocationBloc>().state;
      print('📍 LocationState captured: ${locationState.runtimeType}');
      final distance = locationState is LocationTracking
          ? locationState.totalDistance / 1000
          : 0.0;
      print('📏 Distance: $distance km');

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
      print('LocationState type BEFORE stop: ${locationState.runtimeType}');

      // Ensure loop distance is computed even when start-point tracking is off.
      var loopDistanceToStart = _distanceToStart;
      if (loopDistanceToStart.isInfinite &&
          locationState is LocationTracking &&
          locationState.routePoints.length >= 2) {
        loopDistanceToStart = _calculateDistanceBetweenPoints(
          locationState.routePoints.first,
          locationState.routePoints.last,
        );
        _distanceToStart = loopDistanceToStart;
      }

      // Check if loop was completed (returned within 100m of start)
      final bool loopCompleted = loopDistanceToStart < 100;
      final int newTerritoryCount = _currentSessionTerritories > 0
          ? _currentSessionTerritories
          : (loopCompleted ? 1 : 0); // 1 territory per completed loop

      print(
        '🔄 Loop completed: $loopCompleted (distance to start: ${loopDistanceToStart.toStringAsFixed(1)}m)',
      );

      // If loop completed, create a territory with the actual route shape
      if (_currentSessionTerritories == 0 &&
          _capturedHexIds.isEmpty &&
          loopCompleted &&
          locationState is LocationTracking &&
          locationState.routePoints.isNotEmpty) {
        // Calculate center point of the route
        double sumLat = 0;
        double sumLng = 0;
        for (final point in locationState.routePoints) {
          sumLat += point.latitude;
          sumLng += point.longitude;
        }
        final centerLat = sumLat / locationState.routePoints.length;
        final centerLng = sumLng / locationState.routePoints.length;

        // Generate hex ID for this territory (for uniqueness)
        final hexId = TerritoryGridHelper.getHexId(centerLat, centerLng);
        _capturedHexIds.add(hexId);

        // Store the actual route points for the territory shape
        _territoryRoutePoints = locationState.routePoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

        print(
          '🏆 Territory created: loop shape with ${_territoryRoutePoints.length} points',
        );
      }

      // 1 point per 100 meters walked
      final pointsEarned =
          (distance * 10).round(); // distance in km, so * 10 = per 100m

      print('✅ Territories captured: $newTerritoryCount');
      print('💰 Points earned: $pointsEarned');
      print('🔢 _capturedHexIds.length = ${_capturedHexIds.length}');

      // Capture route points for display BEFORE stopping
      final routePoints = locationState is LocationTracking
          ? locationState.routePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList()
          : <LatLng>[];

      // Show captured area as single filled polygon
      if (routePoints.length >= 3) {
        _showCapturedArea(routePoints);
      }

      // Save activity to history BEFORE stopping location tracking and clearing state
      print('💾 About to call _saveActivityToHistory...');
      print('   - locationState: ${locationState.runtimeType}');
      print('   - distance: $distance');
      print('   - territoriesCount: $newTerritoryCount');
      print('   - routePoints: ${routePoints.length}');
      print('   - capturedHexIds: ${_capturedHexIds.length}');
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

      // NOW clear state and stop tracking AFTER save is complete
      setState(() {
        _trackingState = TrackingState.stopped;
        _currentSpeed = 0.0;
        _capturedHexIds.clear(); // Clear AFTER save
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
        _currentLoopId = null;
        _loopStartIndex = 0;
        _loopStartDistanceMeters = 0.0;
        _loopCaptureInFlight = false;
        _lastLoopCaptureAt = null;
        _reportedHexIds.clear();
        _smoothedCameraTarget = null;
        _smoothedCameraBearing = null;
        _splitIndex = 0;
        _nextSplitAtMeters = _splitDistanceMeters;
        _lastSplitTime = null;
        _lastSplitPace = null;
        _lastSplitDuration = null;
      });

      _buttonAnimController.reverse();
      BackgroundTrackingService.stopTracking();

      // Stop location tracking after save is complete
      context.read<LocationBloc>().add(StopLocationTracking());
      _motionDetection.stopDetection();

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
    } finally {
      if (mounted) {
        setState(() {
          _isEndingSession = false;
        });
      } else {
        _isEndingSession = false;
      }
    }
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
        context.read<LocationBloc>().add(
              StartLocationTracking(
                useSimulation: _useSimulation,
                batterySaver: _batterySaverEnabled,
              ),
            );
        print(
          '${_useSimulation ? "🎮" : "📍"} LocationBloc: StartLocationTracking (${_useSimulation ? "SIMULATION" : "REAL GPS"} MODE, ${_batterySaverEnabled ? "BATTERY SAVER" : "FULL ACCURACY"})',
        );

        // Start ADVANCED motion detection
        _motionDetection.startDetection();
        _motionDetection.resetSteps();
        print('👟 Motion detection started');

        _capturedHexIds.clear();
        _lastDistanceUpdate = 0.0;
        _lastNotificationDistance = 0.0;
        _currentSessionTerritories = 0; // Reset session territories
        _loopStartIndex = 0;
        _loopStartDistanceMeters = 0.0;
        _loopCaptureInFlight = false;
        _lastLoopCaptureAt = null;
        _reportedHexIds.clear();
        _splitIndex = 0;
        _nextSplitAtMeters = _splitDistanceMeters;
        final now = DateTime.now();
        _lastSplitTime = now;
        _lastSplitPace = null;
        _lastSplitDuration = null;
        _trackingStartTime = now;
        _sessionStartSteps = _steps;

        BackgroundTrackingService.startTracking(
          currentDistance: 0.0,
          territoriesCount: 0,
        );

        _recordSelectedRouteUsage();

        print(
          '🚀 ADVANCED TRACKING STARTED - Real-time GPS + Motion Detection Active!',
        );
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
      await _prefs.setString(_offlineSnapshotKey, base64Image);
      _offlineSnapshotBase64 = base64Image;
      HomeWidgetService.updateMapSnapshot(base64Image);
      return base64Image;
    } catch (e) {
      print('❌ Error capturing map screenshot: $e');
      return null;
    }
  }

  List<Position> _limitRoutePoints(List<Position> points) {
    const maxPoints = 2000;
    if (points.length <= maxPoints) {
      return points;
    }

    final step = (points.length / maxPoints).ceil();
    final reduced = <Position>[];
    for (int i = 0; i < points.length; i += step) {
      reduced.add(points[i]);
    }

    if (reduced.isNotEmpty) {
      final last = points.last;
      final lastReduced = reduced.last;
      if (last.latitude != lastReduced.latitude ||
          last.longitude != lastReduced.longitude ||
          last.timestamp != lastReduced.timestamp) {
        reduced.add(last);
      }
    }

    return reduced;
  }

  void _openSyncStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
    );
  }

  void _updateRouteQuality(LocationTracking state) {
    final now = DateTime.now();
    if (_lastQualityUpdate != null &&
        now.difference(_lastQualityUpdate!) < const Duration(seconds: 2)) {
      return;
    }

    if (state.routePoints.length < 3) {
      if (mounted) {
        setState(() {
          _routeQualityScore = 0.0;
          _routeQualityLabel = 'GPS';
          _lastQualityUpdate = now;
        });
      }
      return;
    }

    final recent = state.routePoints
        .sublist(max(0, state.routePoints.length - 30));

    double? avgAccuracy;
    final accuracyValues =
        recent.map((p) => p.accuracy).whereType<double>().toList();
    if (accuracyValues.isNotEmpty) {
      avgAccuracy = accuracyValues.reduce((a, b) => a + b) /
          accuracyValues.length;
    }

    final accuracyScore = avgAccuracy == null
        ? 55.0
        : (1.0 -
                ((avgAccuracy.clamp(5.0, 35.0) - 5.0) /
                    30.0))
            .clamp(0.0, 1.0) *
            100.0;

    double headingChangeSum = 0.0;
    int headingSamples = 0;
    for (int i = 2; i < recent.length; i++) {
      final p0 = recent[i - 2];
      final p1 = recent[i - 1];
      final p2 = recent[i];
      final h1 =
          _calculateBearing(LatLng(p0.latitude, p0.longitude), LatLng(p1.latitude, p1.longitude));
      final h2 =
          _calculateBearing(LatLng(p1.latitude, p1.longitude), LatLng(p2.latitude, p2.longitude));
      final delta = ((h2 - h1 + 540) % 360) - 180;
      headingChangeSum += delta.abs();
      headingSamples += 1;
    }
    final avgHeadingChange =
        headingSamples > 0 ? headingChangeSum / headingSamples : 0.0;
    final smoothScore = (1.0 - (avgHeadingChange / 90.0))
        .clamp(0.0, 1.0) *
        100.0;

    final totalDistance = state.totalDistance;
    final pointsPerKm =
        totalDistance > 0 ? (state.routePoints.length / (totalDistance / 1000)) : 0.0;
    final densityScore = (pointsPerKm / 80.0).clamp(0.0, 1.0) * 100.0;

    final score =
        (accuracyScore * 0.5) + (smoothScore * 0.3) + (densityScore * 0.2);
    final label = score >= 85
        ? 'Elite'
        : score >= 70
            ? 'Great'
            : score >= 55
                ? 'OK'
                : 'Weak';

    if (!mounted) return;
    setState(() {
      _routeQualityScore = score;
      _routeQualityLabel = label;
      _lastQualityUpdate = now;
    });
  }

  void _checkSplitUpdate(LocationTracking state) {
    if (_trackingState != TrackingState.started) return;
    if (_trackingStartTime == null) return;

    while (state.totalDistance >= _nextSplitAtMeters) {
      final now = DateTime.now();
      final lastTime = _lastSplitTime ?? _trackingStartTime ?? now;
      final splitDuration = now.difference(lastTime);
      final pace = _formatPace(splitDuration, _splitDistanceMeters);

      _splitIndex += 1;
      _lastSplitTime = now;
      _lastSplitDuration = splitDuration;
      _lastSplitPace = pace;
      _nextSplitAtMeters = (_splitIndex + 1) * _splitDistanceMeters;

      if (mounted) {
        SystemSound.play(SystemSoundType.click);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split ${_splitIndex} • ${pace}/km'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatPace(Duration duration, double distanceMeters) {
    if (distanceMeters <= 0) return '--:--';
    final paceSeconds = duration.inSeconds / (distanceMeters / 1000.0);
    final minutes = (paceSeconds / 60).floor();
    final seconds = (paceSeconds % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<LatLng> _limitLatLngPoints(List<LatLng> points,
      {int maxPoints = 2000}) {
    if (points.length <= maxPoints) {
      return points;
    }

    final step = (points.length / maxPoints).ceil();
    final reduced = <LatLng>[];
    for (int i = 0; i < points.length; i += step) {
      reduced.add(points[i]);
    }

    if (reduced.isNotEmpty) {
      final last = points.last;
      final lastReduced = reduced.last;
      if (last.latitude != lastReduced.latitude ||
          last.longitude != lastReduced.longitude) {
        reduced.add(last);
      }
    }

    return reduced;
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
    print('🔍 _saveActivityToHistory called');
    print('   LocationState type: ${locationState.runtimeType}');
    print('   Route points: ${routePoints.length}');
    print('   Distance: $distance km');
    print('   Territories count: $territoriesCount');
    print('   Captured hex IDs: ${_capturedHexIds.length}');

    if (locationState is! LocationTracking ||
        locationState.routePoints.isEmpty) {
      print(
        '⚠️ No route data to save - locationState is not LocationTracking or route is empty',
      );
      print('   locationState.runtimeType = ${locationState.runtimeType}');
      if (locationState is LocationTracking) {
        print('   routePoints.length = ${locationState.routePoints.length}');
      }
      return;
    }

    try {
      // Capture map screenshot before saving
      final mapSnapshot = await _captureMapScreenshot();

      final routePointsToSave = _limitRoutePoints(locationState.routePoints);

      final loopId = _currentLoopId ?? _uuid.v4();
      _currentLoopId ??= loopId;

      final activity = Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        clientId: loopId,
        route: routePointsToSave,
        distanceMeters: distance * 1000,
        duration: activeDuration,
        startTime: _trackingStartTime ?? DateTime.now(),
        endTime: DateTime.now(),
        caloriesBurned: (distance * 65).round(),
        averageSpeed: avgSpeed,
        steps: sessionSteps,
        territoriesCaptured: territoriesCount,
        pointsEarned: pointsEarned,
        capturedAreaSqMeters:
            _estimatedAreaSqMeters > 0 ? _estimatedAreaSqMeters : null,
        capturedHexIds:
            _capturedHexIds.isNotEmpty ? _capturedHexIds.toList() : null,
        routeMapSnapshot: mapSnapshot,
      );

      // Always save locally first (offline-safe)
      await _activityLocalDataSource.saveActivity(activity);

      final activityPayload = {
        'clientId': loopId,
        'routePoints': routePointsToSave
            .map(
              (p) => {
                'latitude': p.latitude,
                'longitude': p.longitude,
                'timestamp': p.timestamp.toIso8601String(),
              },
            )
            .toList(),
        'distanceMeters': distance * 1000,
        'duration': '${activeDuration.inSeconds} seconds',
        'startTime': (_trackingStartTime ?? DateTime.now()).toIso8601String(),
        'endTime': DateTime.now().toIso8601String(),
        'caloriesBurned': (distance * 65).round(),
        'averageSpeed': avgSpeed,
        'steps': sessionSteps,
        'territoriesCaptured': territoriesCount,
        'pointsEarned': pointsEarned,
        if (_capturedHexIds.isNotEmpty)
          'capturedHexIds': _capturedHexIds.toList(),
        if (mapSnapshot != null) 'routeMapSnapshot': mapSnapshot,
      };

      // Queue first (offline-safe), then sync in background
      await _offlineSyncService.queueActivityPayload(activityPayload);
      print('[sync] Activity queued for background sync');
      await _refreshSyncStatus();

      // Queue captured territories for background sync
      final unsyncedHexIds = _capturedHexIds.difference(_reportedHexIds);
      if (unsyncedHexIds.isNotEmpty) {
        // FIXED: Decode each hex ID to get its actual center coordinates
        final hexCoordinates = <Map<String, double>>[];
        for (final hexId in unsyncedHexIds) {
          // Use TerritoryGridHelper to get the true center of each hex
          final (centerLat, centerLng) = TerritoryGridHelper.getHexCenter(
            hexId,
          );
          hexCoordinates.add({'lat': centerLat, 'lng': centerLng});
        }

        // Convert route points to API format
        final limitedTerritoryPoints =
            _limitLatLngPoints(_territoryRoutePoints);
        final routePointsArray = limitedTerritoryPoints.isNotEmpty
            ? [
                limitedTerritoryPoints
                    .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                    .toList(),
              ]
            : null;

        final territoryPayload = {
          'hexIds': unsyncedHexIds.toList(),
          'coordinates': hexCoordinates,
          'captureSessionId': loopId,
          if (routePointsArray != null) 'routePoints': routePointsArray,
        };
        await _offlineSyncService.queueTerritoryPayload(territoryPayload);
        _reportedHexIds.addAll(unsyncedHexIds);
        print('[sync] Territories queued for background sync');
        await _refreshSyncStatus();
      } else {
        print('[info] No territories captured during this activity');
      }

      final goalKm = _goalDistanceKm ?? 5.0;
      final progressPercent =
          goalKm > 0 ? ((distance / goalKm) * 100).round() : 0;
      HomeWidgetService.updateStats(
        distanceKm: distance,
        steps: sessionSteps,
        progressPercent: progressPercent.clamp(0, 100).toInt(),
      );
      if (mapSnapshot != null) {
        HomeWidgetService.updateMapSnapshot(mapSnapshot);
      }

      // Kick off background sync without blocking the UI
      _triggerBackgroundSync();
    } catch (e, stackTrace) {
      print('[error] Error saving activity: $e');
      print('[error] Stack trace: $stackTrace');
    }
  }

  Widget _buildPipMode(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locationState) {
        CameraPosition cameraPosition = const CameraPosition(
          target: LatLng(37.7749, -122.4194),
          zoom: 15,
        );

        bool isTracking = false;
        bool isPaused = false;

        if (locationState is LocationIdle &&
            locationState.lastPosition != null) {
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
          isTracking = _trackingState == TrackingState.started;
          isPaused = _trackingState == TrackingState.paused;
        }

        return Stack(
          children: [
            // Map view
            GoogleMap(
              initialCameraPosition: cameraPosition,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              polygons: _polygons,
              polylines: _polylines,
              markers: _currentUserMarker != null
                  ? {_currentUserMarker!}
                  : const <Marker>{},
              mapType: _currentMapType,
              onMapCreated: (GoogleMapController controller) {
                // Don't store controller in PiP mode to avoid conflicts
              },
            ),

            // Minimal tracking indicator
            if (isTracking || isPaused)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPaused ? Colors.orange : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaused ? 'Paused' : 'Tracking',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RouteProjectionResult {
  final LatLng projectedPoint;
  final int segmentIndex;
  final double distanceFromStartMeters;
  final double distanceToRouteMeters;
  final double totalMeters;

  const _RouteProjectionResult({
    required this.projectedPoint,
    required this.segmentIndex,
    required this.distanceFromStartMeters,
    required this.distanceToRouteMeters,
    required this.totalMeters,
  });
}

class _SegmentProjection {
  final LatLng projectedPoint;
  final double t;
  final double distanceMeters;
  final double segmentLengthMeters;

  const _SegmentProjection({
    required this.projectedPoint,
    required this.t,
    required this.distanceMeters,
    required this.segmentLengthMeters,
  });
}

class _HeatCell {
  double count = 0.0;
  double sumLat = 0.0;
  double sumLng = 0.0;
}

class SavedRoute {
  final String id;
  final String name;
  final double distanceKm;
  final bool isPublic;
  final int usageCount;
  final List<LatLng> points;

  SavedRoute({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.isPublic,
    required this.usageCount,
    required this.points,
  });

  factory SavedRoute.fromMap(Map<String, dynamic> map) {
    final rawPoints = map['routePoints'] as List? ?? [];
    final points = rawPoints
        .map(
          (p) => LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
        )
        .toList();

    return SavedRoute(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Route',
      distanceKm: ((map['distanceKm'] ?? 0) as num).toDouble(),
      isPublic: map['isPublic'] == true,
      usageCount: (map['usageCount'] ?? 0) as int,
      points: points,
    );
  }
}
