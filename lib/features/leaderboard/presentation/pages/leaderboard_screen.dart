import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/services/leaderboard_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/widgets/skeleton.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final LeaderboardApiService _apiService;
  late TabController _tabController;
  late final SharedPreferences _prefs;
  static const String _leaderboardCacheKey = 'leaderboard_cache_v1';
  bool _hasCachedLeaderboard = false;
  bool _isRefreshing = false;

  List<LeaderboardUser> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedMetric = 'points';

  @override
  void initState() {
    super.initState();
    _apiService = di.getIt<LeaderboardApiService>();
    _prefs = di.getIt<SharedPreferences>();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadLeaderboardFromCache();
    _refreshLeaderboardFromBackend();
  }

  Future<void> _loadLeaderboardFromCache() async {
    try {
      final cached = _prefs.getString(_leaderboardCacheKey);
      if (cached == null) {
        if (mounted) {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
        }
        return;
      }
      final decoded = jsonDecode(cached) as List<dynamic>;
      final users = decoded
          .map((u) => LeaderboardUser.fromMap(Map<String, dynamic>.from(u)))
          .toList();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _hasError = false;
      });
      _hasCachedLeaderboard = true;
    } catch (e) {
      print('Error reading leaderboard cache: $e');
    }
  }

  Future<void> _refreshLeaderboardFromBackend() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final data = await _apiService.getGlobalLeaderboard(limit: 100);
      final users = data.map((u) => LeaderboardUser.fromMap(u)).toList();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _hasError = false;
      });
      await _prefs.setString(_leaderboardCacheKey, jsonEncode(data));
      _hasCachedLeaderboard = true;
    } catch (e) {
      if (mounted && !_hasCachedLeaderboard) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  List<LeaderboardUser> _getSortedUsers() {
    var users = List<LeaderboardUser>.from(_users);

    switch (_selectedMetric) {
      case 'distance':
        users.sort((a, b) => b.totalDistanceKm.compareTo(a.totalDistanceKm));
        break;
      case 'territories':
        users.sort((a, b) =>
            b.totalTerritoriesCaptured.compareTo(a.totalTerritoriesCaptured));
        break;
      case 'steps':
        users.sort((a, b) => b.totalSteps.compareTo(a.totalSteps));
        break;
      default:
        users.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    }

    // Return subset based on tab
    switch (_tabController.index) {
      case 1:
        return users.take(20).toList();
      case 2:
        return users.take(50).toList();
      default:
        return users;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF7F7F2),
                  Color(0xFFE4F8E8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: -140,
            top: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF9BE15D),
                    Color(0x00F7F7F2),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -120,
            child: Transform.rotate(
              angle: -0.25,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF111827),
                      Color(0xFF1F2937),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildMetricSelector(),
                const SizedBox(height: 8),
                _buildTabBar(),
                const SizedBox(height: 8),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leaderboard',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Top runners by ${_getMetricLabel()}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Spacer(),
          InkWell(
            onTap: _loadData,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.refresh, color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildMetricChip('points', 'Points', Icons.stars),
            const SizedBox(width: 8),
            _buildMetricChip('distance', 'Distance', Icons.alt_route),
            const SizedBox(width: 8),
            _buildMetricChip('territories', 'Areas', Icons.layers),
            const SizedBox(width: 8),
            _buildMetricChip('steps', 'Steps', Icons.directions_walk),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String metric, String label, IconData icon) {
    final isSelected = _selectedMetric == metric;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) {
            setState(() => _selectedMetric = metric);
            HapticFeedback.lightImpact();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF111827) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF111827)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All Time'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLeaderboardSkeleton();
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load leaderboard',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final users = _getSortedUsers();
    final showTopThree = users.length >= 3;
    final rest = showTopThree ? users.sublist(3) : users;

    if (users.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: showTopThree ? _buildTopThree(users) : const SizedBox.shrink(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList.separated(
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rankOffset = showTopThree ? 4 : 1;
                return _buildUserCard(rest[index], index + rankOffset);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree(List<LeaderboardUser> users) {
    if (users.length < 3) return const SizedBox.shrink();
    final topThree = users.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _buildPodiumCard(topThree[1], 2)),
            const SizedBox(width: 12),
            Expanded(child: _buildPodiumCard(topThree[0], 1, isCenter: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildPodiumCard(topThree[2], 3)),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumCard(LeaderboardUser user, int rank, {bool isCenter = false}) {
    final accent = _getRankColor(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(isCenter ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: isCenter ? 42 : 36,
            height: isCenter ? 42 : 36,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getRankEmoji(rank),
                style: TextStyle(fontSize: isCenter ? 18 : 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getMetricValue(user),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text(
            _getMetricLabel(),
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(LeaderboardUser user, int rank) {
    final isTopThree = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTopThree
              ? _getRankColor(rank).withOpacity(0.6)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isTopThree
                  ? _getRankColor(rank)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTopThree
                  ? Text(
                      _getRankEmoji(rank),
                      style: const TextStyle(fontSize: 16),
                    )
                  : Text(
                      '$rank',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${user.level} • ${user.totalTerritoriesCaptured} territories',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getMetricValue(user),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                _getMetricLabel(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMetricValue(LeaderboardUser user) {
    switch (_selectedMetric) {
      case 'distance':
        return '${user.totalDistanceKm.toStringAsFixed(1)} km';
      case 'territories':
        return '${user.totalTerritoriesCaptured}';
      case 'steps':
        return _formatNumber(user.totalSteps);
      default:
        return '${user.totalPoints}';
    }
  }

  String _getMetricLabel() {
    switch (_selectedMetric) {
      case 'distance':
        return 'distance';
      case 'territories':
        return 'territories';
      case 'steps':
        return 'steps';
      default:
        return 'points';
    }
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return '$num';
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFBBF24);
      case 2:
        return const Color(0xFFCBD5F5);
      case 3:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }
  Widget _buildLeaderboardSkeleton() {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => SkeletonBox(
          height: 78,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class LeaderboardUser {
  final String id;
  final String name;
  final String email;
  final int totalPoints;
  final int level;
  final double totalDistanceKm;
  final int totalSteps;
  final int totalTerritoriesCaptured;
  final int totalWorkouts;

  LeaderboardUser({
    required this.id,
    required this.name,
    required this.email,
    required this.totalPoints,
    required this.level,
    required this.totalDistanceKm,
    required this.totalSteps,
    required this.totalTerritoriesCaptured,
    required this.totalWorkouts,
  });

  factory LeaderboardUser.fromMap(Map<String, dynamic> map) {
    return LeaderboardUser(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      email: map['email'] ?? '',
      totalPoints: (map['totalPoints'] ?? 0) as int,
      level: (map['level'] ?? 1) as int,
      totalDistanceKm: ((map['totalDistanceKm'] ?? 0) as num).toDouble(),
      totalSteps: (map['totalSteps'] ?? 0) as int,
      totalTerritoriesCaptured: (map['totalTerritoriesCaptured'] ?? 0) as int,
      totalWorkouts: (map['totalWorkouts'] ?? 0) as int,
    );
  }
}
