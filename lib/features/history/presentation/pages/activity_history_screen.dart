import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../../../core/models/geo_types.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../tracking/domain/entities/activity.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import 'package:intl/intl.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/route_preview.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tracking/data/datasources/activity_local_data_source.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  late final TrackingApiService _apiService;
  final ActivityLocalDataSource _activityLocalDataSource =
      ActivityLocalDataSourceImpl();
  List<Activity> _activities = [];
  bool _isLoading = true;
  bool _isRefreshingActivities = false;
  bool _isOffline = false;
  
  @override
  void initState() {
    super.initState();
    _apiService = di.getIt<TrackingApiService>();
    _loadActivities();
  }
  
  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });
    await _loadLocalActivities();
    _refreshActivitiesFromBackend();
  }

  Future<void> _loadLocalActivities() async {
    try {
      final localActivities = await _activityLocalDataSource.getAllActivities();
      if (!mounted) return;
      setState(() {
        _activities = localActivities;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activities = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshActivitiesFromBackend() async {
    if (_isRefreshingActivities) return;
    if (mounted) {
      setState(() => _isRefreshingActivities = true);
    } else {
      _isRefreshingActivities = true;
    }
    try {
      final activitiesData = await _apiService.getUserActivities();
      final backendActivities =
          activitiesData.map((data) => Activity.fromJson(data)).toList();
      final localActivities = await _activityLocalDataSource.getAllActivities();
      final mergedActivities =
          _mergeActivities(backendActivities, localActivities);
      mergedActivities.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (!mounted) return;
      setState(() {
        _activities = mergedActivities;
        _isLoading = false;
        _isOffline = false;
      });
    } catch (e) {
      print('Could not load activities from backend: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshingActivities = false);
      } else {
        _isRefreshingActivities = false;
      }
    }
  }

  List<Activity> _mergeActivities(
    List<Activity> backend,
    List<Activity> local,
  ) {
    if (local.isEmpty) return backend;
    final existingKeys = <String>{};
    for (final activity in backend) {
      _addActivityKeys(existingKeys, activity);
    }
    final merged = <Activity>[...backend];
    for (final activity in local) {
      if (_hasMatchingKey(existingKeys, activity)) {
        continue;
      }
      merged.add(activity);
    }
    return merged;
  }

  void _addActivityKeys(Set<String> keys, Activity activity) {
    final clientId = activity.clientId;
    if (clientId != null && clientId.isNotEmpty) {
      keys.add('c:$clientId');
    }
    if (activity.id.isNotEmpty) {
      keys.add('i:${activity.id}');
    }
    final timeKey =
        't:${activity.startTime.millisecondsSinceEpoch}-${activity.distanceMeters.round()}';
    keys.add(timeKey);
  }

  bool _hasMatchingKey(Set<String> keys, Activity activity) {
    final clientId = activity.clientId;
    if (clientId != null && clientId.isNotEmpty && keys.contains('c:$clientId')) {
      return true;
    }
    if (activity.id.isNotEmpty && keys.contains('i:${activity.id}')) {
      return true;
    }
    final timeKey =
        't:${activity.startTime.millisecondsSinceEpoch}-${activity.distanceMeters.round()}';
    return keys.contains(timeKey);
  }


  double get _totalDistance => _activities.fold(0.0, (sum, a) => sum + a.distanceMeters / 1000);
  int get _totalActivities => _activities.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? _buildHistorySkeleton()
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRefreshingActivities) ...[
                        const SizedBox(
                          width: 52,
                          height: 52,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Syncing activities...',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Pulling your history from the server',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.directions_run,
                            size: 80,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No activities yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start tracking your runs to see them here',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadActivities,
                  color: AppTheme.primaryColor,
                  child: CustomScrollView(
                    slivers: [
                      // Compact Professional Header
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Colors.white,
                        automaticallyImplyLeading: false,
                        toolbarHeight: 70,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity History',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$_totalActivities workouts - ${_totalDistance.toStringAsFixed(1)} km${_isOffline ? ' - Offline' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
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
                              onShare: () => _shareActivity(activity),
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
  
  void _shareActivity(Activity activity) async {
    final date = DateFormat('MMM d, yyyy').format(activity.startTime);
    final time = DateFormat('h:mm a').format(activity.startTime);
    final distance = (activity.distanceMeters / 1000).toStringAsFixed(2);
    final duration = _formatDuration(activity.duration);
    final speed = activity.averageSpeed.toStringAsFixed(1);
    
    final shareText = '''
🏃‍♂️ PluriHive Activity - $date

📍 Distance: $distance km
⏱️ Time: $duration
⚡ Avg Speed: $speed km/h
🔥 Calories: ${activity.caloriesBurned} cal
${activity.territoriesCaptured > 0 ? '🏴 Territories: ${activity.territoriesCaptured}\n' : ''}${activity.pointsEarned > 0 ? '⭐ Points: ${activity.pointsEarned}\n' : ''}
Started at $time

#PluriHive #Fitness #Running
''';
    
    try {
      final snapshot = activity.routeMapSnapshot;
      if (snapshot != null && snapshot.isNotEmpty) {
        final imageBytes = base64Decode(snapshot);
        final tempDir = await getTemporaryDirectory();
        final file =
            File('${tempDir.path}/plurihive_activity_${activity.id}.png');
        await file.writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
          subject: 'My PluriHive Activity',
        );

        await file.delete();
        return;
      }
    } catch (e) {
      print('Error capturing map screenshot: $e');
    }
    
    // Fallback to text only
    Share.share(shareText, subject: 'My PluriHive Activity');
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildHistorySkeleton() {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonLine(width: 180, height: 14),
              const SizedBox(height: 12),
              SkeletonBox(
                height: 280,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SkeletonBox(
                      height: 60,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SkeletonBox(
                      height: 60,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Activity activity;
  final bool isFirst;
  final VoidCallback onShare;
  
  const _ActivityItem({
    required this.activity,
    this.isFirst = false,
    required this.onShare,
  });

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
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // 3D Map with Route
          if (activity.route.isNotEmpty)
            _Route3DMap(
              activity: activity,
              onShare: onShare,
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
}

// Route Preview Widget with Route Visualization
class _Route3DMap extends StatelessWidget {
  final Activity activity;
  final VoidCallback onShare;
  
  const _Route3DMap({
    required this.activity,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (activity.route.isEmpty) {
      return Container(
        height: 300,
        color: Color(0xFFF3F4F6),
        child: Center(
          child: Icon(Icons.map, size: 48, color: AppTheme.textTertiary),
        ),
      );
    }

    final route = activity.route
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final snapshot = activity.routeMapSnapshot;
    final snapshotBytes =
        snapshot != null && snapshot.isNotEmpty ? base64Decode(snapshot) : null;

    return Stack(
      children: [
        Container(
          height: 300,
          child: RoutePreview(
            routePoints: route,
            snapshotBytes: snapshotBytes,
            lineColor: AppTheme.primaryColor,
            lineWidth: 4,
          ),
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
        // Time badge and Share button
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Share button
              GestureDetector(
                onTap: onShare,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.share, size: 18, color: Colors.white),
                ),
              ),
              SizedBox(width: 8),
              // Time badge
              Container(
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
            ],
          ),
        ),
        // 3D Badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  '3D VIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
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
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}



