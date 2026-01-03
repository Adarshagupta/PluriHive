import 'package:flutter/material.dart';
import '../../../../core/theme/app_constants.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/common_card.dart';
import '../../../../core/widgets/patterned_background.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = [
      Achievement(
        id: 'first_run',
        title: 'First Steps',
        description: 'Complete your first run',
        icon: Icons.directions_run,
        isUnlocked: true,
        progress: 1.0,
      ),
      Achievement(
        id: '5km',
        title: '5K Runner',
        description: 'Run a total of 5 kilometers',
        icon: Icons.flag,
        isUnlocked: false,
        progress: 0.0,
        requirement: '0 / 5 km',
      ),
      Achievement(
        id: '10_territories',
        title: 'Territory Hunter',
        description: 'Capture 10 territories',
        icon: Icons.map,
        isUnlocked: false,
        progress: 0.0,
        requirement: '0 / 10',
      ),
      Achievement(
        id: 'level_5',
        title: 'Rising Star',
        description: 'Reach level 5',
        icon: Icons.stars,
        isUnlocked: false,
        progress: 0.2,
        requirement: 'Level 1 / 5',
      ),
      Achievement(
        id: '1000_calories',
        title: 'Calorie Burner',
        description: 'Burn 1000 calories',
        icon: Icons.local_fire_department,
        isUnlocked: false,
        progress: 0.0,
        requirement: '0 / 1000',
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        icon: Icons.whatshot,
        isUnlocked: false,
        progress: 0.0,
        requirement: '0 / 7 days',
      ),
      Achievement(
        id: '50_territories',
        title: 'Territory Master',
        description: 'Capture 50 territories',
        icon: Icons.emoji_events,
        isUnlocked: false,
        progress: 0.0,
        requirement: '0 / 50',
      ),
      Achievement(
        id: 'marathon',
        title: 'Marathon Runner',
        description: 'Run 42.2 kilometers total',
        icon: Icons.military_tech,
        isUnlocked: false,
        progress: 0.0,
        requirement: '0 / 42.2 km',
      ),
    ];

    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      body: PatternedBackground(
        child: CustomScrollView(
          slivers: [
            CommonSliverAppBar(
              title: 'Achievements',
              subtitle: '$unlockedCount / ${achievements.length} unlocked',
              iconData: Icons.emoji_events,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: AppConstants.spacingMd,
                  mainAxisSpacing: AppConstants.spacingMd,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildAchievementCard(achievements[index]);
                  },
                  childCount: achievements.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return CommonCard(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: achievement.isUnlocked
                  ? const Color(0xFF7FE87A).withOpacity(0.15)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              achievement.icon,
              size: 24,
              color: achievement.isUnlocked
                  ? const Color(0xFF7FE87A)
                  : const Color(0xFF9CA3AF),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: achievement.isUnlocked
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                achievement.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!achievement.isUnlocked &&
                  achievement.requirement != null) ...[
                const SizedBox(height: 8),
                Text(
                  achievement.requirement!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF7FE87A),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final double progress;
  final String? requirement;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    required this.progress,
    this.requirement,
  });
}
