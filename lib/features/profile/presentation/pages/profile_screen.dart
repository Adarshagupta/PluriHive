import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../settings/presentation/pages/settings_screen.dart';
import '../../../../core/services/user_stats_api_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/avatar_preset_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'personal_info_screen.dart';
import 'notifications_screen.dart';
import 'help_support_screen.dart';
import 'avatar_editor_screen.dart';
import '../../../../core/widgets/skeleton.dart';
import '../widgets/google_fit_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statsService = getIt<UserStatsApiService>();
  static const String _statsCacheKey = 'profile_stats_cache_v1';
  late final SharedPreferences _prefs;
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;
  bool _hasCachedStats = false;
  bool _isRefreshingStats = false;

  @override
  void initState() {
    super.initState();
    _prefs = getIt<SharedPreferences>();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await _loadStatsFromCache();
    _refreshStatsFromBackend();
  }

  Future<void> _loadStatsFromCache() async {
    try {
      final cached = _prefs.getString(_statsCacheKey);
      if (cached == null) {
        if (mounted) {
          setState(() => _isLoadingStats = true);
        }
        return;
      }
      final stats = jsonDecode(cached) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
      _hasCachedStats = true;
    } catch (e) {
      print('Error reading stats cache: $e');
    }
  }

  Future<void> _refreshStatsFromBackend() async {
    if (_isRefreshingStats) return;
    _isRefreshingStats = true;
    try {
      final stats = await _statsService.getUserStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
      await _prefs.setString(_statsCacheKey, jsonEncode(stats));
      _hasCachedStats = true;
    } catch (e) {
      if (mounted && !_hasCachedStats) {
        setState(() => _isLoadingStats = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stats: $e')),
        );
      }
    } finally {
      _isRefreshingStats = false;
    }
  }

  Future<void> _refreshProfile() async {
    context.read<AuthBloc>().add(CheckAuthStatus());
    await _loadStats();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '${minutes}m';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Simply pop the current screen
        Navigator.of(context).pop();
        return false; // Prevent default back behavior
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading || state is AuthInitial) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is AuthError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (state is! Authenticated) {
            return const Scaffold(
              body: Center(child: Text('Not authenticated')),
            );
          }

          final user = state.user;

          return Scaffold(
            backgroundColor: const Color(0xFFF7F4EE),
            body: RefreshIndicator(
              onRefresh: _refreshProfile,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                slivers: [
                  _buildProfileHeader(user),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('At a Glance'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _ProfileQuickStat(
                                    label: 'Distance',
                                    value:
                                        '${user.totalDistanceKm.toStringAsFixed(1)} km',
                                    color: const Color(0xFF1F8EF1),
                                  ),
                                  const SizedBox(width: 10),
                                  _ProfileQuickStat(
                                    label: 'Workouts',
                                    value: '${user.totalWorkouts}',
                                    color: const Color(0xFF7FE87A),
                                  ),
                                  const SizedBox(width: 10),
                                  _ProfileQuickStat(
                                    label: 'Territories',
                                    value: '${user.totalTerritoriesCaptured}',
                                    color: const Color(0xFFFFB74D),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _sectionTitle('Performance'),
                              const SizedBox(height: 12),
                              _isLoadingStats
                                  ? _buildProfileStatsSkeleton()
                                  : Column(
                                      children: [
                                        _ProfileMetricCard(
                                          metrics: [
                                            _ProfileMetric(
                                              label: 'Time',
                                              value: _formatDuration(_stats?[
                                                      'totalDurationSeconds'] ??
                                                  0),
                                              icon: Icons.timer,
                                            ),
                                            _ProfileMetric(
                                              label: 'Calories',
                                              value:
                                                  '${_stats?['totalCaloriesBurned'] ?? 0}',
                                              icon: Icons.local_fire_department,
                                            ),
                                            _ProfileMetric(
                                              label: 'Points',
                                              value: '${user.totalPoints}',
                                              icon: Icons.stars,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _ProfileMetricCard(
                                          metrics: [
                                            _ProfileMetric(
                                              label: 'Streak',
                                              value:
                                                  '${_stats?['currentStreak'] ?? 0}d',
                                              icon: Icons.whatshot,
                                            ),
                                            _ProfileMetric(
                                              label: 'Best',
                                              value:
                                                  '${_stats?['longestStreak'] ?? 0}d',
                                              icon: Icons.emoji_events,
                                            ),
                                            _ProfileMetric(
                                              label: 'Skips',
                                              value:
                                                  '${_stats?['streakFreezes'] ?? 0}',
                                              icon: Icons.pause_circle_filled,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 24),
                              _sectionTitle('Health Connect'),
                              const SizedBox(height: 12),
                              GoogleFitCard(margin: EdgeInsets.zero),
                              const SizedBox(height: 24),
                              _sectionTitle('Quick Actions'),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.6,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  _ProfileActionTile(
                                    icon: Icons.face_retouching_natural,
                                    title: 'Avatar',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AvatarEditorScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _ProfileActionTile(
                                    icon: Icons.person_outline,
                                    title: 'Personal',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PersonalInfoScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _ProfileActionTile(
                                    icon: Icons.tune,
                                    title: 'General',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SettingsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _ProfileActionTile(
                                    icon: Icons.notifications_none,
                                    title: 'Notifications',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _ProfileActionTile(
                                    icon: Icons.help_outline,
                                    title: 'Help & Support',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const HelpSupportScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileStatsSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SkeletonShimmer(
        child: Column(
          children: [
            SkeletonBox(
              height: 92,
              borderRadius: BorderRadius.circular(18),
            ),
            const SizedBox(height: 12),
            SkeletonBox(
              height: 92,
              borderRadius: BorderRadius.circular(18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF111827),
      ),
    );
  }

  Widget _buildProfileAvatar(user) {
    final String? source = (user.avatarImageUrl is String &&
            user.avatarImageUrl.isNotEmpty)
        ? user.avatarImageUrl
        : (user.avatarModelUrl is String ? user.avatarModelUrl : null);
    final resolvedUrl = AvatarPresetService.resolveAvatarImageUrl(source);

    if (resolvedUrl.isNotEmpty) {
      if (AvatarPresetService.isAssetPath(resolvedUrl)) {
        final assetPath =
            AvatarPresetService.normalizeAssetPath(resolvedUrl);
        return ClipOval(
          child: Image.asset(
            assetPath,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildAvatarFallback(user),
          ),
        );
      }
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: resolvedUrl,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarFallback(user),
          errorWidget: (context, url, error) => _buildAvatarFallback(user),
        ),
      );
    }
    return _buildAvatarFallback(user);
  }

  Widget _buildAvatarFallback(user) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'P',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildProfileHeader(user) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
          icon: const Icon(
            Icons.settings_outlined,
            color: Color(0xFF111827),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF3D6),
                    Color(0xFFEFFBE6),
                    Color(0xFFF7F4EE),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF7FE87A).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -20,
              top: 80,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F8EF1).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                child: Row(
                  children: [
                    _buildProfileAvatar(user),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.name,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _ProfileBadge(
                                icon: Icons.stars,
                                label: 'Level ${user.level}',
                              ),
                              _ProfileBadge(
                                icon: Icons.bolt,
                                label: '${user.totalPoints} pts',
                              ),
                            ],
                          ),
                        ],
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
}

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF111827)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileQuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProfileQuickStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  final List<_ProfileMetric> metrics;

  const _ProfileMetricCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: metrics
            .map(
              (metric) => Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(metric.icon,
                          size: 18, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      metric.value,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProfileMetric {
  final String label;
  final String value;
  final IconData icon;

  _ProfileMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
