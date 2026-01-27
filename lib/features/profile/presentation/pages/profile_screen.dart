import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../settings/presentation/pages/settings_screen.dart';
import '../../../../core/services/user_stats_api_service.dart';
import '../../../../core/di/injection_container.dart';
import 'personal_info_screen.dart';
import 'notifications_screen.dart';
import 'help_support_screen.dart';
import '../../../../core/widgets/skeleton.dart';
import '../widgets/google_fit_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statsService = getIt<UserStatsApiService>();
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _statsService.getUserStats();
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stats: $e')),
        );
      }
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
          if (state is! Authenticated) {
            return const Scaffold(
              body: Center(child: Text('Not authenticated')),
            );
          }

          final user = state.user;

          return Scaffold(
            backgroundColor: Colors.white,
            body: RefreshIndicator(
              onRefresh: _refreshProfile,
              color: Color(0xFF7FE87A),
              child: CustomScrollView(
                slivers: [
                  // Minimal Header
                  SliverAppBar(
                    expandedHeight: 200,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    pinned: true,
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
                        icon: Icon(
                          Icons.settings_outlined,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Simple Circle Avatar
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Color(0xFF7FE87A),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  user.name[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 48),

                        // Stats
                        _isLoadingStats
                            ? _buildProfileStatsSkeleton()
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(
                                      _formatDuration(
                                          _stats?['totalDurationSeconds'] ?? 0),
                                      'Time',
                                    ),
                                    Container(
                                        width: 1,
                                        height: 40,
                                        color: Color(0xFFE5E7EB)),
                                    _buildStatItem(
                                      '${_stats?['totalCaloriesBurned'] ?? 0}',
                                      'Calories',
                                    ),
                                    Container(
                                        width: 1,
                                        height: 40,
                                        color: Color(0xFFE5E7EB)),
                                    _buildStatItem(
                                      '${_stats?['totalWorkouts'] ?? 0}',
                                      'Workouts',
                                    ),
                                  ],
                                ),
                              ),

                        const SizedBox(height: 24),

                        if (!_isLoadingStats)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  '${_stats?['currentStreak'] ?? 0}d',
                                  'Streak',
                                ),
                                Container(
                                    width: 1,
                                    height: 40,
                                    color: Color(0xFFE5E7EB)),
                                _buildStatItem(
                                  '${_stats?['longestStreak'] ?? 0}d',
                                  'Best',
                                ),
                                Container(
                                    width: 1,
                                    height: 40,
                                    color: Color(0xFFE5E7EB)),
                                _buildStatItem(
                                  '${_stats?['streakFreezes'] ?? 0}',
                                  'Skips',
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 32),

                        // Google Fit Integration
                        GoogleFitCard(),

                        const SizedBox(height: 32),

                        // Menu Items
                        _buildMenuItem(
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

                        _buildMenuItem(
                          icon: Icons.tune,
                          title: 'General',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),

                        _buildMenuItem(
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

                        _buildMenuItem(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HelpSupportScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 100),
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

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Row(
          children: [
            Icon(
              icon,
              color: Color(0xFF111827),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStatsSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: SkeletonShimmer(
        child: Column(
          children: [
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
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonBox(
                    height: 60,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
        ),
      ),
    );
  }
}
