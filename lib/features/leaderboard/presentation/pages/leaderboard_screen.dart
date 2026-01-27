import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  List<LeaderboardUser> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedMetric = 'points';

  @override
  void initState() {
    super.initState();
    _apiService = di.getIt<LeaderboardApiService>();
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
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final data = await _apiService.getGlobalLeaderboard(limit: 100);
      final users = data.map((u) => LeaderboardUser.fromMap(u)).toList();

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Leaderboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[700]),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMetricSelector(),
          _buildTabBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildMetricChip('points', 'Points'),
          const SizedBox(width: 8),
          _buildMetricChip('distance', 'Distance'),
          const SizedBox(width: 8),
          _buildMetricChip('territories', 'Areas'),
          const SizedBox(width: 8),
          _buildMetricChip('steps', 'Steps'),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String metric, String label) {
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
            color: isSelected ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.grey[800],
        labelColor: Colors.grey[900],
        unselectedLabelColor: Colors.grey[500],
        tabs: const [
          Tab(text: 'All Time'),
          Tab(text: 'Weekly'),
          Tab(text: 'Monthly'),
        ],
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          return _buildUserCard(users[index], index + 1);
        },
      ),
    );
  }

  Widget _buildUserCard(LeaderboardUser user, int rank) {
    final isTopThree = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isTopThree
            ? Border.all(color: _getRankColor(rank), width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTopThree ? _getRankColor(rank) : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTopThree
                  ? Text(_getRankEmoji(rank),
                      style: const TextStyle(fontSize: 16))
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${user.level} • ${user.totalTerritoriesCaptured} territories',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                _getMetricLabel(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
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
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.orange[700]!;
      default:
        return Colors.grey[300]!;
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
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => SkeletonBox(
          height: 72,
          borderRadius: BorderRadius.circular(12),
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
