import 'package:flutter/material.dart';
import '../../../../core/widgets/patterned_background.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Future<void> _refreshLeaderboard() async {
    // Simulate refresh delay
    await Future.delayed(Duration(milliseconds: 500));
    // In a real app, this would reload data from API
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mock data for leaderboard
    final leaderboard = [
      LeaderboardEntry(
          rank: 1,
          name: 'lilyone1w...',
          points: 146,
          territories: 234,
          avatar: '🙋',
          emoji: '👋'),
      LeaderboardEntry(
          rank: 2,
          name: 'josheleve...',
          points: 105,
          territories: 221,
          avatar: '👨‍💼',
          emoji: ''),
      LeaderboardEntry(
          rank: 3,
          name: 'herotaylo...',
          points: 99,
          territories: 198,
          avatar: '😎',
          emoji: '😊'),
      LeaderboardEntry(
          rank: 4,
          name: 'whitefish664',
          points: 96,
          territories: 0,
          avatar: '👨',
          emoji: ''),
      LeaderboardEntry(
          rank: 5,
          name: 'sadpanda176',
          points: 88,
          territories: 167,
          avatar: '🐼',
          emoji: ''),
      LeaderboardEntry(
          rank: 6,
          name: 'silverduck204',
          points: 87,
          territories: 156,
          avatar: '🦆',
          emoji: ''),
      LeaderboardEntry(
          rank: 7,
          name: 'beautifulmouse112',
          points: 85,
          territories: 142,
          avatar: '🐭',
          emoji: ''),
    ];

    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: _refreshLeaderboard,
        color: Color(0xFF667EEA),
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.white,
              toolbarHeight: 70,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Compete with players worldwide',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // Top 3 Podium
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  children: [
                    // Winner podium
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 2nd Place
                        Expanded(child: _buildPodiumItem(leaderboard[1], 2)),
                        SizedBox(width: 12),
                        // 1st Place (taller)
                        Expanded(child: _buildPodiumItem(leaderboard[0], 1)),
                        SizedBox(width: 12),
                        // 3rd Place
                        Expanded(child: _buildPodiumItem(leaderboard[2], 3)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Other Rankings Header
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Other Rankings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            // Rest of rankings
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = leaderboard[index + 3];
                    return _buildListItem(entry, index == leaderboard.length - 4);
                  },
                  childCount: leaderboard.length - 3,
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumItem(LeaderboardEntry entry, int rank) {
    final rankData = {
      1: {'height': 140.0, 'color': Color(0xFFFCD34D), 'icon': '👑', 'label': '1st'},
      2: {'height': 100.0, 'color': Color(0xFFE5E7EB), 'icon': '🥈', 'label': '2nd'},
      3: {'height': 80.0, 'color': Color(0xFFCD7F32), 'icon': '🥉', 'label': '3rd'},
    };
    
    final data = rankData[rank]!;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: rank == 1 
                ? [Color(0xFF667EEA), Color(0xFF764BA2)]
                : [Color(0xFF9CA3AF), Color(0xFF6B7280)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              entry.avatar,
              style: TextStyle(fontSize: 28),
            ),
          ),
        ),
        SizedBox(height: 8),
        // Name
        Text(
          entry.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        // Points
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xFF667EEA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${entry.points} pts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 8),
        // Podium
        Container(
          height: data['height'] as double,
          decoration: BoxDecoration(
            color: (data['color'] as Color).withOpacity(0.2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: data['color'] as Color, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data['icon'] as String,
                  style: TextStyle(fontSize: 32),
                ),
                SizedBox(height: 4),
                Text(
                  data['label'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: data['color'] as Color == Color(0xFFE5E7EB)
                      ? Color(0xFF6B7280)
                      : data['color'] as Color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(LeaderboardEntry entry, bool isLast) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 12),
          
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE5E7EB), Color(0xFFD1D5DB)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.avatar,
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
          SizedBox(width: 12),
          
          // Name and territories
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${entry.territories} territories',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Points
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${entry.points}',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class LeaderboardEntry {
  final int rank;
  final String name;
  final int points;
  final int territories;
  final String avatar;
  final String emoji;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    required this.territories,
    required this.avatar,
    this.emoji = '',
    this.isCurrentUser = false,
  });
}
