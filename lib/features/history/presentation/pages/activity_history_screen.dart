import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../tracking/domain/entities/activity.dart';
import '../../../tracking/data/datasources/activity_local_data_source.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import 'package:intl/intl.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  late final TrackingApiService _apiService;
  final ActivityLocalDataSource _localDataSource = ActivityLocalDataSourceImpl();
  List<Activity> _activities = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _apiService = di.getIt<TrackingApiService>();
    _loadActivities();
  }
  
  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      // Try to load from backend first
      try {
        final activitiesData = await _apiService.getUserActivities();
        final backendActivities = activitiesData.map((data) => Activity.fromJson(data)).toList();
        
        if (backendActivities.isNotEmpty) {
          setState(() {
            _activities = backendActivities;
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        print('⚠️ Could not load from backend: $e');
      }
      
      // Fallback to local storage
      final localActivities = await _localDataSource.getAllActivities();
      setState(() {
        _activities = localActivities;
        _isLoading = false;
      });
      print('📱 Loaded ${localActivities.length} activities from local storage');
    } catch (e) {
      print('❌ Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  double get _totalDistance => _activities.fold(0.0, (sum, a) => sum + a.distanceMeters / 1000);
  int get _totalActivities => _activities.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF667EEA)),
              ),
            )
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_run,
                          size: 80,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No activities yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start tracking your runs to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadActivities,
                  color: Color(0xFF667EEA),
                  child: CustomScrollView(
                    slivers: [
                      // Compact Professional Header
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Colors.white,
                        toolbarHeight: 70,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity History',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$_totalActivities workouts • ${_totalDistance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Activities List
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final activity = _activities[index];
                            return _ActivityItem(
                              activity: activity,
                              isFirst: index == 0,
                            );
                          },
                          childCount: _activities.length,
                        ),
                      ),
                      // Bottom padding
                      SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Activity activity;
  final bool isFirst;
  
  const _ActivityItem({required this.activity, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: isFirst ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header (if different from previous)
          Padding(
            padding: EdgeInsets.fromLTRB(24, isFirst ? 0 : 24, 24, 12),
            child: Text(
              DateFormat('EEEE, MMMM d, yyyy').format(activity.startTime),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Map Screenshot
          if (activity.routeMapSnapshot != null)
            Stack(
              children: [
                Image.memory(
                  base64Decode(activity.routeMapSnapshot!),
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Color(0xFFF3F4F6),
                      child: Center(
                        child: Icon(Icons.map, size: 48, color: Color(0xFF9CA3AF)),
                      ),
                    );
                  },
                ),
                // Gradient overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                // Time badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          DateFormat('h:mm a').format(activity.startTime),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Main stats overlay
                Positioned(
                  bottom: 20,
                  left: 24,
                  right: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _OverlayStat(
                        icon: Icons.straighten,
                        value: '${(activity.distanceMeters / 1000).toStringAsFixed(2)}',
                        label: 'km',
                      ),
                      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                      _OverlayStat(
                        icon: Icons.timer,
                        value: _formatDuration(activity.duration),
                        label: '',
                      ),
                      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                      _OverlayStat(
                        icon: Icons.speed,
                        value: '${activity.averageSpeed.toStringAsFixed(1)}',
                        label: 'km/h',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          // Additional stats section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CompactStat(
                  icon: Icons.local_fire_department,
                  value: '${activity.caloriesBurned}',
                  label: 'cal',
                  color: Color(0xFFEF4444),
                ),
                if (activity.territoriesCaptured > 0)
                  _CompactStat(
                    icon: Icons.flag,
                    value: '${activity.territoriesCaptured}',
                    label: 'areas',
                    color: Color(0xFF8B5CF6),
                  ),
                if (activity.pointsEarned > 0)
                  _CompactStat(
                    icon: Icons.stars,
                    value: '${activity.pointsEarned}',
                    label: 'pts',
                    color: Color(0xFFFCD34D),
                  ),
                if (activity.capturedAreaSqMeters != null)
                  _CompactStat(
                    icon: Icons.map,
                    value: '${(activity.capturedAreaSqMeters! / 1000).toStringAsFixed(1)}',
                    label: 'km²',
                    color: Color(0xFF06B6D4),
                  ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 1,
            color: Color(0xFFE5E7EB),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _OverlayStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  
  const _OverlayStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  
  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
