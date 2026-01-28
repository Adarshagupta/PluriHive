import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActivityDetailDrawer extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityDetailDrawer({super.key, required this.activity});

  String _formatDuration(String duration) {
    try {
      final match = RegExp(r'(\d+)').firstMatch(duration);
      if (match != null) {
        final seconds = int.parse(match.group(1)!);
        final hours = seconds ~/ 3600;
        final minutes = (seconds % 3600) ~/ 60;
        final secs = seconds % 60;
        
        if (hours > 0) {
          return '${hours}h ${minutes}m ${secs}s';
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
      return DateFormat('MMM dd, yyyy • HH:mm').format(date);
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
    // Extract user/owner info
    final user = activity['user'] as Map<String, dynamic>?;
    
    // Debug logging
    print('🔍 Activity data keys: ${activity.keys.toList()}');
    print('👤 User data: $user');
    
    // Use name if available, otherwise use email, otherwise 'Unknown User'
    String ownerName = 'Unknown User';
    if (user != null) {
      if (user['name'] != null && user['name'].toString().isNotEmpty) {
        ownerName = user['name'];
      } else if (user['email'] != null && user['email'].toString().isNotEmpty) {
        ownerName = user['email'].toString().split('@')[0]; // Use email username part
      }
    }
    final ownerEmail = user?['email']?.toString() ?? '';
    final clientId = activity['clientId']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // Header with Owner Info
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.directions_run,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workout Activity',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(activity['startTime'] ?? activity['createdAt']),
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Owner info
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        radius: 20,
                        child: Text(
                          ownerName.isNotEmpty ? ownerName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ownerName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            if (ownerEmail.isNotEmpty)
                              Text(
                                ownerEmail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (clientId != null && clientId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Client ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          clientId,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Stats Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                // Row 1
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: _formatDistance(activity['distanceMeters']),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.timer,
                        label: 'Duration',
                        value: _formatDuration(activity['duration'] ?? '0'),
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.local_fire_department,
                        label: 'Calories',
                        value: '${activity['caloriesBurned'] ?? 0}',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.speed,
                        label: 'Avg Speed',
                        value: '${_formatSpeed(activity['averageSpeed'])} m/s',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 3
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.directions_walk,
                        label: 'Steps',
                        value: '${activity['steps'] ?? 0}',
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.hexagon,
                        label: 'Territories',
                        value: '${activity['territoriesCaptured'] ?? 0}',
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
