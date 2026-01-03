import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../bloc/location_bloc.dart';

class TrackingControls extends StatelessWidget {
  final VoidCallback onStartTracking;
  final VoidCallback onStopTracking;
  
  const TrackingControls({
    super.key,
    required this.onStartTracking,
    required this.onStopTracking,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        final isTracking = state is LocationTracking;
        
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTracking) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Distance: ${(state.totalDistance / 1000).toStringAsFixed(2)} km',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Points captured: ${state.routePoints.length}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ).animate(
                  onPlay: (controller) => controller.repeat(),
                ).shimmer(duration: 2000.ms),
                const SizedBox(height: 16),
              ],
              
              Material(
                elevation: 8,
                shape: const CircleBorder(),
                color: isTracking ? Colors.red : Colors.green,
                child: InkWell(
                  onTap: isTracking ? onStopTracking : onStartTracking,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTracking ? Icons.stop : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).animate()
                .scale(duration: 300.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 8),
              
              Text(
                isTracking ? 'Stop Tracking' : 'Start Tracking',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isTracking ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
