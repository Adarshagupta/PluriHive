import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/widgets/skeleton.dart';

class ActivityHistorySheet extends StatefulWidget {
  const ActivityHistorySheet({super.key});

  @override
  State<ActivityHistorySheet> createState() => _ActivityHistorySheetState();
}

class _ActivityHistorySheetState extends State<ActivityHistorySheet> {
  final _trackingService = di.getIt<TrackingApiService>();
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final activities = await _trackingService.getUserActivities(limit: 100);
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDuration(String duration) {
    try {
      // Parse duration string (format: "X seconds" or interval format)
      final match = RegExp(r'(\d+)').firstMatch(duration);
      if (match != null) {
        final seconds = int.parse(match.group(1)!);
        final hours = seconds ~/ 3600;
        final minutes = (seconds % 3600) ~/ 60;
        final secs = seconds % 60;
        
        if (hours > 0) {
          return '${hours}h ${minutes}m';
        } else if (minutes > 0) {
          return '${minutes}m ${secs}s';
        } else {
          return '${secs}s';
        }
      }
      return duration;
    } catch (e) {
      return duration;
    }
  }

  String _formatDistance(dynamic distanceMeters) {
    try {
      double distance;
      if (distanceMeters is String) {
        distance = double.parse(distanceMeters);
      } else if (distanceMeters is num) {
        distance = distanceMeters.toDouble();
      } else {
        distance = 0.0;
      }
      
      if (distance >= 1000) {
        return '${(distance / 1000).toStringAsFixed(2)} km';
      } else {
        return '${distance.toStringAsFixed(0)} m';
      }
    } catch (e) {
      return '0 m';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(Duration(days: 1));
      final activityDate = DateTime(date.year, date.month, date.day);
      
      if (activityDate == today) {
        return 'Today ${DateFormat('HH:mm').format(date)}';
      } else if (activityDate == yesterday) {
        return 'Yesterday ${DateFormat('HH:mm').format(date)}';
      } else {
        return DateFormat('MMM dd, yyyy HH:mm').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _formatSpeed(dynamic speed) {
    try {
      if (speed == null) return '0.0';
      if (speed is String) {
        return double.parse(speed).toStringAsFixed(1);
      } else if (speed is num) {
        return speed.toDouble().toStringAsFixed(1);
      }
      return '0.0';
    } catch (e) {
      return '0.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF7FE87A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.history,
                    color: Color(0xFF7FE87A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '${_activities.length} ${_activities.length == 1 ? 'activity' : 'activities'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          // Activities List
          Expanded(
            child: _isLoading
                ? _buildSheetSkeleton()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Color(0xFFEF4444),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load activities',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _error = null;
                                  });
                                  _loadActivities();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF7FE87A),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _activities.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.directions_run,
                                    size: 64,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No activities yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start your first workout to see it here!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() => _isLoading = true);
                              await _loadActivities();
                            },
                            color: Color(0xFF7FE87A),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _activities.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final activity = _activities[index];
                                return _buildActivityCard(activity);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return GestureDetector(
      onTap: () {
        // Close the sheet and navigate to map with this activity's route
        Navigator.pop(context, activity);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF7FE87A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.directions_run,
                      color: Color(0xFF7FE87A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          _formatDate(activity['startTime'] ?? activity['createdAt']),
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          
          Divider(height: 1),
          
          // Stats Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: _formatDistance(activity['distanceMeters']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.timer,
                        label: 'Duration',
                        value: _formatDuration(activity['duration'] ?? '0'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.local_fire_department,
                        label: 'Calories',
                        value: '${activity['caloriesBurned'] ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.hexagon,
                        label: 'Territories',
                        value: '${activity['territoriesCaptured'] ?? 0}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.directions_walk,
                        label: 'Steps',
                        value: '${activity['steps'] ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.speed,
                        label: 'Avg Speed',
                        value: '${_formatSpeed(activity['averageSpeed'])} m/s',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Color(0xFF7FE87A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetSkeleton() {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return SkeletonBox(
            height: 160,
            borderRadius: BorderRadius.circular(16),
          );
        },
      ),
    );
  }
}
