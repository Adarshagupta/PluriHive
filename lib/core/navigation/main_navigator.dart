import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../../features/tracking/presentation/pages/map_screen.dart';
import '../../features/leaderboard/presentation/pages/leaderboard_screen.dart';
import '../../features/achievements/presentation/pages/achievements_screen.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(CheckAuthStatus());
    _screens = [
      DashboardScreen(),
      MapScreen(onNavigateHome: () {
        setState(() {
          _currentIndex = 0;
        });
      }),
      LeaderboardScreen(),
      AchievementsScreen(),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Handle auth state changes if needed
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _currentIndex == 1
            ? null
            : Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      icon: Icons.cottage_rounded,
                      index: 0,
                      color: Color(0xFF7FE87A),
                    ),
                    _buildNavItem(
                      icon: Icons.explore_rounded,
                      index: 1,
                      color: Color(0xFF64B5F6),
                    ),
                    _buildNavItem(
                      icon: Icons.emoji_events_rounded,
                      index: 2,
                      color: Color(0xFFFFA726),
                    ),
                    _buildNavItem(
                      icon: Icons.star_rounded,
                      index: 3,
                      color: Color(0xFFAB47BC),
                    ),
                    _buildNavItem(
                      icon: Icons.sentiment_satisfied_rounded,
                      index: 4,
                      color: Color(0xFF66BB6A),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required Color color,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : color,
          size: 26,
        ),
      ),
    );
  }
}
