import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/patterned_background.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/services/google_fit_service.dart';
import '../../../../core/services/websocket_service.dart';
import 'package:health/health.dart';
import '../../../game/presentation/bloc/game_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../tracking/presentation/bloc/location_bloc.dart';
import '../../../tracking/domain/entities/activity.dart';
import '../../../tracking/data/datasources/activity_local_data_source.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import 'dart:async';
import '../../../history/presentation/pages/activity_history_screen.dart';
import '../../../../core/widgets/rain_overlay.dart';

class HomeTab extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeTab({super.key, this.onNavigateToTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _animController;
  late TrackingApiService _trackingApiService;
  final ActivityLocalDataSource _activityLocalDataSource =
      ActivityLocalDataSourceImpl();
  late GoogleFitService _googleFitService;
  late WebSocketService _webSocketService;
  late final void Function(dynamic) _statsUpdateListener;
  late SharedPreferences _prefs;
  Map<String, dynamic>? _weatherData;
  bool _isNight = false;
  String _greeting = 'Good morning';
  List<Activity> _recentActivities = [];
  bool _isLoadingActivities = false;
  bool _hasLocalRecentActivities = false;
  bool _isRefreshingRecentActivities = false;
  bool _isLoadingHealth = false;
  bool _healthConnected = false;
  HealthConnectSdkStatus? _healthConnectStatus;
  Map<String, dynamic>? _healthSummary;
  List<HeartRateSample> _heartRateSamples = [];
  late List<String> _sectionOrder;

  static const String _homeSectionOrderKey = 'home_section_order';
  static const List<String> _defaultSectionOrder = [
    'progress',
    'miniStats',
    'weeklyGoal',
    'health',
    'territory',
    'recentActivity',
  ];

  @override
  void initState() {
    super.initState();
    _trackingApiService = di.getIt<TrackingApiService>();
    _googleFitService = di.getIt<GoogleFitService>();
    _webSocketService = di.getIt<WebSocketService>();
    _prefs = di.getIt<SharedPreferences>();
    _sectionOrder = _loadSectionOrder();
    _statsUpdateListener = (_) {
      if (!mounted) return;
      _loadRecentActivities();
    };
    _webSocketService.onUserStatsUpdate(_statsUpdateListener);
    _animController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animController.forward();
    // Load game data when home tab initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWeather();
      _loadRecentActivities();
      _loadHealthSummary();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController?.dispose();
    _webSocketService.offUserStatsUpdate(_statsUpdateListener);
    super.dispose();
  }

  Future<void> _refreshData() async {
    context.read<GameBloc>().add(LoadGameData());
    await _fetchWeather();
    await _loadRecentActivities();
    await _loadHealthSummary();
  }

  Future<void> _loadHealthSummary() async {
    setState(() => _isLoadingHealth = true);
    try {
      final status = await _googleFitService.getHealthConnectStatus();
      _healthConnectStatus = status;

      if (status != null && status != HealthConnectSdkStatus.sdkAvailable) {
        setState(() {
          _healthConnected = false;
          _healthSummary = null;
          _heartRateSamples = [];
          _isLoadingHealth = false;
        });
        return;
      }

      final connected = await _googleFitService.checkReadAuthorization();
      if (!connected) {
        setState(() {
          _healthConnected = false;
          _healthSummary = null;
          _heartRateSamples = [];
          _isLoadingHealth = false;
        });
        return;
      }

      final results = await Future.wait([
        _googleFitService.getTodaySteps(),
        _googleFitService.getTodayDistance(),
        _googleFitService.getTodayCalories(),
      ]);
      List<HeartRateSample> samples = [];
      final hasHeartAccess = await _googleFitService.checkHeartRateAccess();
      if (hasHeartAccess) {
        samples = await _googleFitService.getTodayHeartRateSamples();
      }

      setState(() {
        _healthConnected = true;
        _healthSummary = {
          'steps': results[0],
          'distance': results[1],
          'calories': results[2],
        };
        _heartRateSamples = samples;
        _isLoadingHealth = false;
      });
    } catch (e) {
      print('Error loading Health Connect data: $e');
      setState(() => _isLoadingHealth = false);
    }
  }

  Future<void> _connectHealthConnect() async {
    setState(() => _isLoadingHealth = true);
    try {
      final status = await _googleFitService.getHealthConnectStatus();
      _healthConnectStatus = status;

      if (status != null && status != HealthConnectSdkStatus.sdkAvailable) {
        if (!mounted) return;
        final needsUpdate = status ==
            HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;
        final message = needsUpdate
            ? 'Health Connect needs an update to work. Update it to continue.'
            : 'Health Connect is not installed. Install it to continue.';

        final install = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Health Connect Required'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(needsUpdate ? 'Update' : 'Install'),
              ),
            ],
          ),
        );

        if (install == true) {
          await _googleFitService.promptInstallHealthConnect();
        }

        if (mounted) {
          setState(() => _isLoadingHealth = false);
        }
        return;
      }

      final success = await _googleFitService.initialize();
      if (success) {
        await _loadHealthSummary();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Health Connect permissions not granted'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isLoadingHealth = false);
      }
    } catch (e) {
      print('Error connecting Health Connect: $e');
      if (mounted) {
        setState(() => _isLoadingHealth = false);
      }
    }
  }

  Future<void> _loadRecentActivities() async {
    await _loadRecentActivitiesFromLocal();
    _refreshRecentActivitiesFromBackend();
  }

  Future<void> _loadRecentActivitiesFromLocal() async {
    try {
      final localActivities = await _activityLocalDataSource.getAllActivities();
      localActivities.sort((a, b) => b.startTime.compareTo(a.startTime));
      if (!mounted) return;
      setState(() {
        _recentActivities = localActivities.take(3).toList();
        _isLoadingActivities = _recentActivities.isEmpty;
      });
      _hasLocalRecentActivities = _recentActivities.isNotEmpty;
    } catch (e) {
      print('Error loading local activities: $e');
      if (mounted) {
        setState(() => _isLoadingActivities = true);
      }
    }
  }

  Future<void> _refreshRecentActivitiesFromBackend() async {
    if (_isRefreshingRecentActivities) return;
    _isRefreshingRecentActivities = true;
    try {
      final activitiesData =
          await _trackingApiService.getUserActivities(limit: 3);
      final activities =
          activitiesData.map((data) => Activity.fromJson(data)).toList();
      for (final activity in activities) {
        await _activityLocalDataSource.saveActivity(activity);
      }
      if (!mounted) return;
      if (activities.isNotEmpty || !_hasLocalRecentActivities) {
        setState(() {
          _recentActivities = activities;
          _isLoadingActivities = false;
        });
      } else {
        setState(() => _isLoadingActivities = false);
      }
    } catch (e) {
      print('Error loading recent activities: $e');
      if (mounted && !_hasLocalRecentActivities) {
        setState(() => _isLoadingActivities = false);
      }
    } finally {
      _isRefreshingRecentActivities = false;
    }
  }

  List<String> _loadSectionOrder() {
    final stored = _prefs.getStringList(_homeSectionOrderKey);
    if (stored == null || stored.isEmpty) {
      return List<String>.from(_defaultSectionOrder);
    }

    final seen = <String>{};
    final valid = <String>[];
    for (final id in stored) {
      if (_defaultSectionOrder.contains(id) && seen.add(id)) {
        valid.add(id);
      }
    }

    for (final id in _defaultSectionOrder) {
      if (!valid.contains(id)) {
        valid.add(id);
      }
    }

    return valid;
  }

  Future<void> _saveSectionOrder() async {
    await _prefs.setStringList(_homeSectionOrderKey, _sectionOrder);
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex == 0) return;
    if (newIndex == 0) newIndex = 1;

    final adjustedOldIndex = oldIndex - 1;
    var adjustedNewIndex = newIndex - 1;
    if (newIndex > oldIndex) {
      adjustedNewIndex -= 1;
    }

    setState(() {
      final item = _sectionOrder.removeAt(adjustedOldIndex);
      _sectionOrder.insert(adjustedNewIndex, item);
    });

    _saveSectionOrder();
  }

  double _sectionSpacing(String id) {
    if (id == 'recentActivity') {
      return 40;
    }
    return 24;
  }

  Widget _buildHeaderItem() {
    return Column(
      key: const ValueKey('home_header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with gradient background
        Stack(
          children: [
            // Weather gradient overlay
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: _getWeatherGradient(),
              ),
            ),
            if (_isRaining())
              Positioned.fill(
                child: IgnorePointer(
                  child: RainOverlay(
                    intensity: _rainIntensity(),
                    color: Colors.white,
                    slant: 0.12,
                  ),
                ),
              ),
            // Header content on top of gradient
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, authState) {
                            final userName = authState is Authenticated
                                ? (authState.user.name.isNotEmpty
                                    ? authState.user.name
                                    : 'Runner')
                                : 'Runner';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_greeting,',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionItem(String id, int listIndex) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('section_$id'),
      index: listIndex,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: _sectionSpacing(id),
        ),
        child: _buildSectionContent(id),
      ),
    );
  }

  Widget _buildSectionContent(String id) {
    switch (id) {
      case 'progress':
        return _buildProgressSection();
      case 'miniStats':
        return _buildMiniStatsSection();
      case 'weeklyGoal':
        return _buildWeeklyGoalSection();
      case 'health':
        return _buildHealthConnectCard();
      case 'territory':
        return _buildTerritoryStatsSection();
      case 'recentActivity':
        return _buildRecentActivitySection();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build home tab UI
    return Scaffold(
      body: PatternedBackground(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: ReorderableListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _onReorder,
            itemCount: _sectionOrder.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeaderItem();
              }
              final sectionId = _sectionOrder[index - 1];
              return _buildSectionItem(sectionId, index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (state is! GameLoaded) {
          return _buildProgressSkeleton();
        }

        // Use the progress calculation from UserStats
        final stats = state.stats;
        final progress = stats.progressToNextLevel;
        final currentLevel = stats.level;
        final xpForNextLevel = stats.nextLevelXP;
        final currentXP = stats.totalPoints % xpForNextLevel;

        print(
            '📊 Progress Debug: Level=$currentLevel, TotalPoints=${stats.totalPoints}, CurrentXP=$currentXP, NextLevelXP=$xpForNextLevel, Progress=$progress (${(progress * 100).toInt()}%)');

        // Calculate points progress for the circular indicator
        final pointsProgress = xpForNextLevel > 0
            ? (stats.totalPoints / xpForNextLevel).clamp(0.0, 1.0)
            : 0.0;

        final now = DateTime.now();
        final dateStr = '${now.day} ${_getMonthName(now.month)}';

        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFFB8E6E6),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.trending_up,
                                size: 20,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Your Progress',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down,
                                size: 18, color: Colors.black54),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  // Circular progress for calories
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: pointsProgress,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${state.stats.totalPoints}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Points',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.local_fire_department,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatsSection() {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (state is! GameLoaded) {
          return _buildMiniStatsSkeleton();
        }
        // Debug: Print the actual distance value
        print(
            '🏠 HOME TAB: Displaying distance = ${state.stats.totalDistanceKm} km');
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_run,
                            size: 18, color: Colors.black54),
                        SizedBox(width: 8),
                        Text(
                          'Total\nDistance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${state.stats.totalDistanceKm.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'km',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up,
                                    size: 12, color: Colors.black54),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Lifetime',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (widget.onNavigateToTab != null) {
                    widget.onNavigateToTab!(2);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ActivityHistoryScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 18, color: Colors.black54),
                          SizedBox(width: 8),
                          Text(
                            'Captured\nAreas',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.history, size: 16, color: Colors.black38),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${state.stats.territoriesCaptured}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'zones',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined,
                                      size: 12, color: Colors.black54),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${state.stats.currentStreak} day streak',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyGoalSection() {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (state is! GameLoaded) {
          return _buildWeeklyGoalSkeleton();
        }
        final weeklyGoal = 50.0; // km
        final currentWeekly = state.stats.totalDistanceKm % weeklyGoal;
        final progress = (currentWeekly / weeklyGoal).clamp(0.0, 1.0);

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_outlined,
                          color: Color(0xFF7FE87A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Weekly Goal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${currentWeekly.toStringAsFixed(1)}/${weeklyGoal.toStringAsFixed(0)} km',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFB8E6E6),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${((progress) * 100).toInt()}% complete',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTerritoryStatsSection() {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (state is! GameLoaded) {
          return _buildTerritoryStatsSkeleton();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Territory Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TerritoryStatCard(
                    icon: Icons.square_outlined,
                    value: '${state.stats.territoriesCaptured}',
                    label: 'Captured',
                    color: Color(0xFF7FE87A),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _TerritoryStatCard(
                    icon: Icons.shield_outlined,
                    value: '${state.stats.currentStreak}',
                    label: 'Day Streak',
                    color: Color(0xFF6DD5ED),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _TerritoryStatCard(
                    icon: Icons.star_outline,
                    value: '${state.stats.totalPoints}',
                    label: 'Points',
                    color: Color(0xFFFFB84D),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingActivities
            ? _buildRecentActivitySkeleton()
            : _recentActivities.isEmpty
                ? Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.directions_run,
                            size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No activities yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Start your first workout!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _recentActivities.map((activity) {
                      final distanceKm = activity.distanceMeters / 1000;
                      final durationMin = activity.duration.inMinutes;
                      final timeAgo = _getTimeAgo(activity.startTime);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _RecentActivityCard(
                          icon: Icons.directions_run,
                          title: 'Workout',
                          subtitle:
                              '${distanceKm.toStringAsFixed(1)} km • $durationMin min',
                          time: timeAgo,
                          color: Color(0xFF7FE87A),
                        ),
                      );
                    }).toList(),
                  ),
      ],
    );
  }

  Widget _buildProgressSkeleton() {
    return SkeletonShimmer(
      child: SkeletonBox(
        height: 170,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildMiniStatsSkeleton() {
    return SkeletonShimmer(
      child: Row(
        children: [
          Expanded(
            child: SkeletonBox(
              height: 120,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SkeletonBox(
              height: 120,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoalSkeleton() {
    return SkeletonShimmer(
      child: SkeletonBox(
        height: 120,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildTerritoryStatsSkeleton() {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLine(width: 140, height: 16),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SkeletonBox(
                  height: 90,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonBox(
                  height: 90,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonBox(
                  height: 90,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySkeleton() {
    return SkeletonShimmer(
      child: Column(
        children: const [
          SkeletonBox(
              height: 88, borderRadius: BorderRadius.all(Radius.circular(16))),
          SizedBox(height: 8),
          SkeletonBox(
              height: 88, borderRadius: BorderRadius.all(Radius.circular(16))),
          SizedBox(height: 8),
          SkeletonBox(
              height: 88, borderRadius: BorderRadius.all(Radius.circular(16))),
        ],
      ),
    );
  }

  Widget _buildHealthConnectCard() {
    final status = _healthConnectStatus;
    final needsUpdate =
        status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;

    if (_isLoadingHealth) {
      return _buildHealthConnectSkeleton();
    }

    if (status != null && status != HealthConnectSdkStatus.sdkAvailable) {
      return _buildHealthConnectUnavailable(needsUpdate);
    }

    if (!_healthConnected) {
      return _buildHealthConnectDisconnected();
    }

    final steps = (_healthSummary?['steps'] ?? 0) as int;
    final distanceMeters = (_healthSummary?['distance'] ?? 0.0) as double;
    final calories = (_healthSummary?['calories'] ?? 0.0) as double;
    final distanceKm = distanceMeters / 1000;

    final heartStats = _computeHeartRateStats();
    final hasHeartData = _heartRateSamples.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite,
                    color: Color(0xFF4CAF50), size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Health Connect',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadHealthSummary,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HealthStatItem(
                label: 'Steps',
                value: '$steps',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              _HealthStatItem(
                label: 'Distance',
                value: '${distanceKm.toStringAsFixed(1)} km',
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(width: 8),
              _HealthStatItem(
                label: 'Calories',
                value: '${calories.toInt()}',
                color: const Color(0xFFFF9800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Heart Rate',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (!hasHeartData)
            Text(
              'No heart rate data today',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 70,
                    child: _HeartRateSparkline(samples: _heartRateSamples),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${heartStats['last']} bpm',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'avg ${heartStats['avg']}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      '${heartStats['min']} - ${heartStats['max']}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      '${_heartRateSamples.length} readings',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectDisconnected() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Connect',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to see steps, distance, calories, and heart rate.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _connectHealthConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Connect'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectUnavailable(bool needsUpdate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Connect',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            needsUpdate
                ? 'Health Connect needs an update to work on this device.'
                : 'Health Connect is not installed.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _connectHealthConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(needsUpdate ? 'Update' : 'Install'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectSkeleton() {
    return SkeletonShimmer(
      child: SkeletonBox(
        height: 180,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Map<String, int> _computeHeartRateStats() {
    if (_heartRateSamples.isEmpty) {
      return {'avg': 0, 'min': 0, 'max': 0, 'last': 0};
    }
    int min = _heartRateSamples.first.bpm;
    int max = _heartRateSamples.first.bpm;
    int sum = 0;
    for (final sample in _heartRateSamples) {
      sum += sample.bpm;
      if (sample.bpm < min) min = sample.bpm;
      if (sample.bpm > max) max = sample.bpm;
    }
    final avg = (sum / _heartRateSamples.length).round();
    return {
      'avg': avg,
      'min': min,
      'max': max,
      'last': _heartRateSamples.last.bpm,
    };
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _fetchWeather() async {
    try {
      // Get precise current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 10));

      print('Location: ${position.latitude}, ${position.longitude}');

      final apiKey = '5031f2deb028a21f969207e55fa35755';
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric';

      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Weather data: $data');

        // Determine time of day
        final now = DateTime.now();
        final sunrise =
            DateTime.fromMillisecondsSinceEpoch(data['sys']['sunrise'] * 1000);
        final sunset =
            DateTime.fromMillisecondsSinceEpoch(data['sys']['sunset'] * 1000);
        final isNight = now.isBefore(sunrise) || now.isAfter(sunset);

        // Set greeting based on time
        String greeting;
        final hour = now.hour;
        if (hour < 12) {
          greeting = 'Good morning';
        } else if (hour < 17) {
          greeting = 'Good afternoon';
        } else {
          greeting = 'Good evening';
        }

        if (mounted) {
          setState(() {
            _weatherData = data;
            _isNight = isNight;
            _greeting = greeting;
          });
        }
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
  }

  LinearGradient _getWeatherGradient() {
    if (_weatherData == null) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
          Colors.transparent,
        ],
        stops: [0.0, 0.5, 1.0],
      );
    }

    final weatherMain =
        _weatherData!['weather'][0]['main'].toString().toLowerCase();

    if (_isNight) {
      if (weatherMain.contains('cloud')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C3E50).withOpacity(0.45),
            Color(0xFF34495E).withOpacity(0.30),
            Color(0xFF34495E).withOpacity(0.15),
            Colors.transparent,
          ],
          stops: [0.0, 0.4, 0.7, 1.0],
        );
      }
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1A237E).withOpacity(0.45),
          Color(0xFF283593).withOpacity(0.30),
          Color(0xFF283593).withOpacity(0.15),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      );
    }

    if (weatherMain.contains('rain')) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF536976).withOpacity(0.45),
          Color(0xFFBBD2C5).withOpacity(0.30),
          Color(0xFFBBD2C5).withOpacity(0.15),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      );
    } else if (weatherMain.contains('cloud')) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF757F9A).withOpacity(0.45),
          Color(0xFFD7DDE8).withOpacity(0.30),
          Color(0xFFD7DDE8).withOpacity(0.15),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      );
    } else if (weatherMain.contains('clear')) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF56CCF2).withOpacity(0.45),
          Color(0xFF2F80ED).withOpacity(0.30),
          Color(0xFF2F80ED).withOpacity(0.15),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      );
    }

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.4),
        Colors.white.withOpacity(0.2),
        Colors.transparent,
      ],
      stops: [0.0, 0.5, 1.0],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  Widget _getWeatherIcon() {
    if (_weatherData == null) return SizedBox();

    final weatherMain =
        _weatherData!['weather'][0]['main'].toString().toLowerCase();

    IconData icon;
    if (_isNight) {
      icon = Icons.nightlight_round;
    } else if (weatherMain.contains('rain')) {
      icon = Icons.water_drop;
    } else if (weatherMain.contains('cloud')) {
      icon = Icons.cloud;
    } else if (weatherMain.contains('clear')) {
      icon = Icons.wb_sunny;
    } else {
      icon = Icons.wb_cloudy;
    }

    return Icon(
      icon,
      size: 120,
      color: Colors.white,
    );
  }

  String _getAqiCategory(int aqi) {
    // US AQI scale (0-500)
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  bool _isRaining() {
    if (_weatherData == null) return false;
    final weatherMain =
        _weatherData!['weather'][0]['main'].toString().toLowerCase();
    return weatherMain.contains('rain') ||
        weatherMain.contains('drizzle') ||
        weatherMain.contains('thunder');
  }

  double _rainIntensity() {
    if (_weatherData == null) return 0.4;
    final weatherMain =
        _weatherData!['weather'][0]['main'].toString().toLowerCase();
    final description =
        _weatherData!['weather'][0]['description'].toString().toLowerCase();
    if (weatherMain.contains('thunder') || description.contains('heavy')) {
      return 0.75;
    }
    if (weatherMain.contains('drizzle') || description.contains('light')) {
      return 0.35;
    }
    return 0.55;
  }

}

// Quick Action Button

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Territory Stat Card
class _TerritoryStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _TerritoryStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// Recent Activity Card
class _RecentActivityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _RecentActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartRateSparkline extends StatelessWidget {
  final List<HeartRateSample> samples;

  const _HeartRateSparkline({required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Not enough data',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _HeartRateSparklinePainter(samples: samples),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _HeartRateSparklinePainter extends CustomPainter {
  final List<HeartRateSample> samples;

  _HeartRateSparklinePainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const maxPoints = 30;
    List<HeartRateSample> points = samples;
    if (samples.length > maxPoints) {
      final step = (samples.length / maxPoints).ceil();
      points = [];
      for (int i = 0; i < samples.length; i += step) {
        points.add(samples[i]);
      }
      if (points.last.time != samples.last.time) {
        points.add(samples.last);
      }
    }

    int min = points.first.bpm;
    int max = points.first.bpm;
    for (final sample in points) {
      if (sample.bpm < min) min = sample.bpm;
      if (sample.bpm > max) max = sample.bpm;
    }

    final range = (max - min).clamp(1, 200);
    final path = Path();

    for (int i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final normalized = (points[i].bpm - min) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartRateSparklinePainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

// Line graph painter for progress visualization
class _LineGraphPainter extends CustomPainter {
  final double progress;

  _LineGraphPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw background line
    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.3,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.4,
    );
    canvas.drawPath(path, paint);

    // Draw progress line
    final progressPath = Path();
    progressPath.moveTo(0, size.height * 0.7);
    final progressWidth = size.width * progress;
    if (progressWidth > size.width * 0.5) {
      progressPath.quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.3,
        size.width * 0.5,
        size.height * 0.5,
      );
      progressPath.quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.7,
        progressWidth,
        size.height * 0.4 + (size.width - progressWidth) * 0.001,
      );
    } else if (progressWidth > size.width * 0.25) {
      progressPath.quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.3,
        progressWidth,
        size.height * 0.5 - (size.width * 0.5 - progressWidth) * 0.4,
      );
    } else {
      progressPath.quadraticBezierTo(
        progressWidth,
        size.height * 0.3,
        progressWidth,
        size.height * 0.7 - progressWidth * 1.6,
      );
    }
    canvas.drawPath(progressPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Stats card with bar chart
class _StatsCardWithChart extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final List<Color> gradient;
  final List<double> chartData;

  const _StatsCardWithChart({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.gradient,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Spacer(),
          // Bar chart
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: chartData.map((height) {
              return Container(
                width: 8,
                height: 40 * height,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Calendar card with mini calendar
class _CalendarCard extends StatelessWidget {
  final int streak;

  const _CalendarCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFB6C1).withOpacity(0.6),
            Color(0xFFFFC0CB).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFB6C1).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white70, size: 18),
              SizedBox(width: 6),
              Text(
                'Streak',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Spacer(),
          // Mini calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final isActive = index < streak % 8;
              return Container(
                decoration: BoxDecoration(
                  color:
                      isActive ? Colors.white : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? Color(0xFFFFB6C1)
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 8),
          Text(
            '$streak days',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
