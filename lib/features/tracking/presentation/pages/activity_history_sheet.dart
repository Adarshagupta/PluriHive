import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/widgets/skeleton.dart';
import '../../data/datasources/activity_local_data_source.dart';
import '../../domain/entities/activity.dart';

class ActivityHistorySheet extends StatefulWidget {
  const ActivityHistorySheet({super.key});

  @override
  State<ActivityHistorySheet> createState() => _ActivityHistorySheetState();
}

class _ActivityHistorySheetState extends State<ActivityHistorySheet> {
  final _trackingService = di.getIt<TrackingApiService>();
  final ActivityLocalDataSource _localDataSource = ActivityLocalDataSourceImpl();
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String? _error;

  static const Color _accent = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final activities = await _trackingService.getUserActivities(limit: 100);
      for (final data in activities) {
        try {
          final activity = Activity.fromJson(data);
          await _localDataSource.saveActivity(activity);
        } catch (e) {
          print('[warn] Failed to cache activity locally: $e');
        }
      }
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      try {
        final localActivities = await _localDataSource.getAllActivities();
        setState(() {
          _activities =
              localActivities.map((activity) => activity.toJson()).toList();
          _isLoading = false;
          _error = null;
        });
        return;
      } catch (localError) {
        print('[warn] Failed to load local activities: $localError');
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDuration(String duration) {
    try {
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
    } catch (_) {
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
      }
      return '${distance.toStringAsFixed(0)} m';
    } catch (_) {
      return '0 m';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final activityDate = DateTime(date.year, date.month, date.day);

      if (activityDate == today) {
        return 'Today ${DateFormat('HH:mm').format(date)}';
      } else if (activityDate == yesterday) {
        return 'Yesterday ${DateFormat('HH:mm').format(date)}';
      }
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (_) {
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
    } catch (_) {
      return '0.0';
    }
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height * 0.85;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + media.viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
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
                          _accent.withOpacity(0.18),
                          _accent.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: sheetHeight,
                  child: Column(
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
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.history,
                                color: _accent,
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
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '${_activities.length} ${_activities.length == 1 ? 'activity' : 'activities'}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _isLoading
                            ? _buildSheetSkeleton()
                            : _error != null
                                ? _buildErrorState()
                                : _activities.isEmpty
                                    ? _buildEmptyState()
                                    : RefreshIndicator(
                                        onRefresh: () async {
                                          setState(() => _isLoading = true);
                                          await _loadActivities();
                                        },
                                        color: _accent,
                                        child: ListView.separated(
                                          padding: const EdgeInsets.all(20),
                                          itemCount: _activities.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(height: 14),
                                          itemBuilder: (context, index) {
                                            final activity = _activities[index];
                                            return _buildActivityCard(activity);
                                          },
                                        ),
                                      ),
                      ),
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

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context, activity);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    color: _accent,
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
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _formatDate(activity['startTime'] ?? activity['createdAt']),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildStatChip(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: _formatDistance(activity['distanceMeters']),
                  color: const Color(0xFF2563EB),
                ),
                _buildStatChip(
                  icon: Icons.timer,
                  label: 'Duration',
                  value: _formatDuration(activity['duration'] ?? '0'),
                  color: const Color(0xFFF59E0B),
                ),
                _buildStatChip(
                  icon: Icons.directions_walk,
                  label: 'Steps',
                  value: '${activity['steps'] ?? 0}',
                  color: const Color(0xFF7C3AED),
                ),
                _buildStatChip(
                  icon: Icons.hexagon,
                  label: 'Territories',
                  value: '${activity['territoriesCaptured'] ?? 0}',
                  color: const Color(0xFF14B8A6),
                ),
                _buildStatChip(
                  icon: Icons.local_fire_department,
                  label: 'Calories',
                  value: '${activity['caloriesBurned'] ?? 0}',
                  color: const Color(0xFFEF4444),
                ),
                _buildStatChip(
                  icon: Icons.speed,
                  label: 'Avg Speed',
                  value: '${_formatSpeed(activity['averageSpeed'])} m/s',
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetSkeleton() {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return SkeletonBox(
            height: 150,
            borderRadius: BorderRadius.circular(18),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_run,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'No activities yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your first workout to see it here!',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load activities',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: const Color(0xFF64748B),
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
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
