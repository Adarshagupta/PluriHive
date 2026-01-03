import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../game/presentation/bloc/game_bloc.dart';

class StatsOverlay extends StatelessWidget {
  const StatsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (state is! GameLoaded) {
          return const SizedBox.shrink();
        }
        
        final stats = state.stats;
        
        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.stars,
                      label: 'Level',
                      value: stats.level.toString(),
                      color: Colors.amber,
                    ),
                    _StatItem(
                      icon: Icons.emoji_events,
                      label: 'Points',
                      value: _formatNumber(stats.totalPoints),
                      color: Colors.purple,
                    ),
                    _StatItem(
                      icon: Icons.map,
                      label: 'Territories',
                      value: stats.territoriesCaptured.toString(),
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.directions_run,
                      label: 'Distance',
                      value: '${stats.totalDistanceKm.toStringAsFixed(1)} km',
                      color: Colors.blue,
                    ),
                    _StatItem(
                      icon: Icons.local_fire_department,
                      label: 'Calories',
                      value: _formatNumber(stats.totalCaloriesBurned),
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress to Level ${stats.level + 1}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${(stats.progressToNextLevel * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: stats.progressToNextLevel,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.2, end: 0);
      },
    );
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
