import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/widgets/patterned_background.dart';
import '../../../game/presentation/bloc/game_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../tracking/presentation/bloc/location_bloc.dart';
import '../../../tracking/domain/entities/activity.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import 'dart:async';

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
  Map<String, dynamic>? _weatherData;
  bool _isNight = false;
  String _greeting = 'Good morning';
  List<Activity> _recentActivities = [];
  bool _isLoadingActivities = false;

  @override
  void initState() {
    super.initState();
    _trackingApiService = di.getIt<TrackingApiService>();
    _animController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animController.forward();
    // Load game data when home tab initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameBloc>().add(LoadGameData());
      _fetchWeather();
      _loadRecentActivities();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _refreshData() async {
    context.read<GameBloc>().add(LoadGameData());
    await _fetchWeather();
    await _loadRecentActivities();
  }
  
  Future<void> _loadRecentActivities() async {
    setState(() => _isLoadingActivities = true);
    try {
      final activitiesData = await _trackingApiService.getUserActivities(limit: 3);
      final activities = activitiesData.map((data) => Activity.fromJson(data)).toList();
      setState(() {
        _recentActivities = activities;
        _isLoadingActivities = false;
      });
    } catch (e) {
      print('Error loading recent activities: $e');
      setState(() => _isLoadingActivities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build home tab UI
    return Scaffold(
      body: PatternedBackground(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header with gradient background
              Stack(
                children: [
                  // Weather gradient overlay
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: _getWeatherGradient(),
                    ),
                  ),
                  // Header content on top of gradient
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
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
                                      ? (authState.user.name.isNotEmpty ? authState.user.name : 'Runner')
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Your Progress Card
                    BlocBuilder<GameBloc, GameState>(
                      builder: (context, state) {
                        if (state is! GameLoaded) {
                          return SizedBox.shrink();
                        }
                        
                        // Use the progress calculation from UserStats
                        final stats = state.stats;
                        final progress = stats.progressToNextLevel;
                        final currentLevel = stats.level;
                        final xpForNextLevel = stats.nextLevelXP;
                        final currentXP = stats.totalPoints % xpForNextLevel;
                        
                        print('📊 Progress Debug: Level=$currentLevel, TotalPoints=${stats.totalPoints}, CurrentXP=$currentXP, NextLevelXP=$xpForNextLevel, Progress=$progress (${(progress * 100).toInt()}%)');
                            
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
                        ),

                        const SizedBox(height: 16),

                        // Weight and Calories Cards
                        BlocBuilder<GameBloc, GameState>(
                          builder: (context, state) {
                            if (state is! GameLoaded) {
                              return SizedBox.shrink();
                            }
                            // Debug: Print the actual distance value
                            print('🏠 HOME TAB: Displaying distance = ${state.stats.totalDistanceKm} km');
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
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Quick Actions
                        Text(
                          'Quick Actions',
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
                              child: _QuickActionButton(
                                icon: Icons.play_arrow_rounded,
                                label: 'Start Run',
                                color: Color(0xFF7FE87A),
                                onTap: () {
                                  // Start location tracking
                                  context.read<LocationBloc>().add(StartLocationTracking());
                                  // Navigate to Map tab (index 1)
                                  widget.onNavigateToTab?.call(1);
                                },
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.map_outlined,
                                label: 'View Map',
                                color: Color(0xFF6DD5ED),
                                onTap: () {
                                  // Navigate to Map tab (index 1)
                                  widget.onNavigateToTab?.call(1);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.emoji_events_outlined,
                                label: 'Achievements',
                                color: Color(0xFFFFB84D),
                                onTap: () {
                                  // Navigate to Leaderboard tab (index 2)
                                  widget.onNavigateToTab?.call(2);
                                },
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.history,
                                label: 'History',
                                color: Color(0xFF9D7BEA),
                                onTap: () {
                                  // Navigate to Profile tab (index 3)
                                  widget.onNavigateToTab?.call(3);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Weekly Goal
                        BlocBuilder<GameBloc, GameState>(
                          builder: (context, state) {
                            if (state is! GameLoaded) {
                              return SizedBox.shrink();
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
                                        Color(0xFF7FE87A),
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
                        ),

                        const SizedBox(height: 24),

                        // Territory Stats
                        BlocBuilder<GameBloc, GameState>(
                          builder: (context, state) {
                            if (state is! GameLoaded) {
                              return SizedBox.shrink();
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
                        ),

                        const SizedBox(height: 24),

                        // Recent Activity
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
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
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
                                        Icon(Icons.directions_run, size: 40, color: Colors.grey),
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
                                          subtitle: '${distanceKm.toStringAsFixed(1)} km • $durationMin min',
                                          time: timeAgo,
                                          color: Color(0xFF7FE87A),
                                        ),
                                      );
                                    }).toList(),
                                  ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric';
      
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Weather data: $data');
        
        // Determine time of day
        final now = DateTime.now();
        final sunrise = DateTime.fromMillisecondsSinceEpoch(data['sys']['sunrise'] * 1000);
        final sunset = DateTime.fromMillisecondsSinceEpoch(data['sys']['sunset'] * 1000);
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
    
    final weatherMain = _weatherData!['weather'][0]['main'].toString().toLowerCase();
    
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
  
  Widget _getWeatherIcon() {
    if (_weatherData == null) return SizedBox();
    
    final weatherMain = _weatherData!['weather'][0]['main'].toString().toLowerCase();
    
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
