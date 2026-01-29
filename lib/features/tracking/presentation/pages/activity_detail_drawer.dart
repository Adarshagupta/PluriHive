import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      }
      if (speed is num) {
        return speed.toDouble().toStringAsFixed(1);
      }
      return '0.0';
    } catch (_) {
      return '0.0';
    }
  }

  String? _resolveAvatarSource() {
    final user = activity['user'];
    final candidates = <dynamic>[
      if (user is Map) user['avatarImageUrl'],
      if (user is Map) user['avatarModelUrl'],
      if (user is Map) user['avatarUrl'],
      if (user is Map) user['profilePicture'],
      if (user is Map) user['photoUrl'],
      activity['avatarImageUrl'],
      activity['avatarModelUrl'],
      activity['avatarUrl'],
      activity['profilePicture'],
      activity['photoUrl'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Widget _buildAvatar(String? avatarSource, Color accent, String fallbackInitial) {
    final resolved = avatarSource?.trim();
    final hasAvatar = resolved != null && resolved.isNotEmpty;
    final isAssetPath = hasAvatar && resolved!.startsWith('assets/');

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
                ? Image.asset(resolved!, fit: BoxFit.cover)
                : Image.network(
                    resolved!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: Icon(Icons.person, color: accent, size: 28),
                    ),
                  ))
            : Container(
                color: const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: Text(
                  fallbackInitial.isNotEmpty
                      ? fallbackInitial[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
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

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF16A34A);
    final user = activity['user'] as Map<String, dynamic>?;
    String ownerName = 'Unknown User';
    if (user != null) {
      if (user['name'] != null && user['name'].toString().isNotEmpty) {
        ownerName = user['name'];
      } else if (user['email'] != null && user['email'].toString().isNotEmpty) {
        ownerName = user['email'].toString().split('@')[0];
      }
    }
    final ownerEmail = user?['email']?.toString() ?? '';
    final clientId = activity['clientId']?.toString();
    final avatarSource = _resolveAvatarSource();

    final distanceText = _formatDistance(activity['distanceMeters']);
    final durationText = _formatDuration(activity['duration'] ?? '0');
    final stepsText = '${activity['steps'] ?? 0}';
    final territoriesText = '${activity['territoriesCaptured'] ?? 0}';
    final caloriesText = '${activity['caloriesBurned'] ?? 0}';
    final avgSpeedText = '${_formatSpeed(activity['averageSpeed'])} m/s';
    final pointsText = activity['pointsEarned'] != null
        ? '${activity['pointsEarned']}'
        : null;

    final dateSource = activity['startTime'] ?? activity['createdAt'];
    final dateText = dateSource != null ? _formatDate(dateSource) : '';

    final media = MediaQuery.of(context);
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildAvatar(avatarSource, accent, ownerName),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Workout Activity',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Logged by $ownerName',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    if (ownerEmail.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          ownerEmail,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatusChip(
                                label: 'Workout',
                                icon: Icons.directions_run,
                                color: accent,
                              ),
                              if (dateText.isNotEmpty)
                                _buildStatusChip(
                                  label: dateText,
                                  icon: Icons.calendar_today,
                                  color: const Color(0xFF0EA5E9),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildStatChip(
                                icon: Icons.straighten,
                                label: 'Distance',
                                value: distanceText,
                                color: const Color(0xFF2563EB),
                              ),
                              _buildStatChip(
                                icon: Icons.timer,
                                label: 'Duration',
                                value: durationText,
                                color: const Color(0xFFF59E0B),
                              ),
                              _buildStatChip(
                                icon: Icons.directions_walk,
                                label: 'Steps',
                                value: stepsText,
                                color: const Color(0xFF7C3AED),
                              ),
                              _buildStatChip(
                                icon: Icons.hexagon,
                                label: 'Territories',
                                value: territoriesText,
                                color: const Color(0xFF14B8A6),
                              ),
                              _buildStatChip(
                                icon: Icons.local_fire_department,
                                label: 'Calories',
                                value: caloriesText,
                                color: const Color(0xFFEF4444),
                              ),
                              _buildStatChip(
                                icon: Icons.speed,
                                label: 'Avg Speed',
                                value: avgSpeedText,
                                color: const Color(0xFF10B981),
                              ),
                              if (pointsText != null)
                                _buildStatChip(
                                  icon: Icons.stars,
                                  label: 'Points',
                                  value: pointsText,
                                  color: const Color(0xFFF59E0B),
                                ),
                            ],
                          ),
                          if (clientId != null && clientId.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              icon: Icons.tag,
                              label: 'Client ID',
                              value: clientId,
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                    foregroundColor: const Color(0xFF111827),
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
  }
}
