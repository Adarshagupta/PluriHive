import 'package:equatable/equatable.dart';
import 'position.dart';

class Activity extends Equatable {
  final String id;
  final String? clientId;
  final List<Position> route;
  final double distanceMeters;
  final Duration duration;
  final DateTime startTime;
  final DateTime? endTime;
  final int caloriesBurned;
  final double averageSpeed;
  final int steps;
  final int territoriesCaptured;
  final int pointsEarned;
  final double? capturedAreaSqMeters;
  final List<String>? capturedHexIds;
  final String? routeMapSnapshot; // Base64 encoded image of route
  
  const Activity({
    required this.id,
    this.clientId,
    required this.route,
    required this.distanceMeters,
    required this.duration,
    required this.startTime,
    this.endTime,
    required this.caloriesBurned,
    required this.averageSpeed,
    this.steps = 0,
    this.territoriesCaptured = 0,
    this.pointsEarned = 0,
    this.capturedAreaSqMeters,
    this.capturedHexIds,
    this.routeMapSnapshot,
  });
  
  @override
  List<Object?> get props => [
    id,
    clientId,
    route,
    distanceMeters,
    duration,
    startTime,
    endTime,
    caloriesBurned,
    averageSpeed,
    steps,
    territoriesCaptured,
    pointsEarned,
    capturedAreaSqMeters,
    capturedHexIds,
    routeMapSnapshot,
  ];
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'route': route.map((p) => p.toJson()).toList(),
    'distanceMeters': distanceMeters,
    'durationSeconds': duration.inSeconds,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'caloriesBurned': caloriesBurned,
    'averageSpeed': averageSpeed,
    'steps': steps,
    'territoriesCaptured': territoriesCaptured,
    'pointsEarned': pointsEarned,
    'capturedAreaSqMeters': capturedAreaSqMeters,
    'capturedHexIds': capturedHexIds,
    'routeMapSnapshot': routeMapSnapshot,
  };
  
  factory Activity.fromJson(Map<String, dynamic> json) {
    // Handle both local storage format and backend format
    final routeData = json['route'] ?? json['routePoints'];
    final route = (routeData as List).map((p) => Position.fromJson(p)).toList();
    
    // Parse duration - handle multiple formats
    Duration parsedDuration;
    if (json['duration'] != null) {
      final durationStr = json['duration'].toString().trim();
      
      if (durationStr.contains(':')) {
        // Format: "HH:MM:SS" or "MM:SS"
        final parts = durationStr.split(':');
        if (parts.length == 3) {
          final hours = int.parse(parts[0]);
          final minutes = int.parse(parts[1]);
          final seconds = double.parse(parts[2]).floor();
          parsedDuration = Duration(hours: hours, minutes: minutes, seconds: seconds);
        } else {
          final minutes = int.parse(parts[0]);
          final seconds = double.parse(parts[1]).floor();
          parsedDuration = Duration(minutes: minutes, seconds: seconds);
        }
      } else if (durationStr.toLowerCase().contains('seconds')) {
        // Format: "86 seconds"
        final secondsStr = durationStr.toLowerCase().replaceAll('seconds', '').trim();
        parsedDuration = Duration(seconds: int.parse(secondsStr));
      } else {
        // Fallback: pure number as seconds
        parsedDuration = Duration(seconds: int.parse(durationStr));
      }
    } else if (json['durationSeconds'] != null) {
      parsedDuration = Duration(seconds: json['durationSeconds']);
    } else {
      parsedDuration = Duration.zero;
    }
    
    return Activity(
      id: json['id'].toString(),
      clientId: json['clientId']?.toString(),
      route: route,
      distanceMeters: (json['distanceMeters'] is String) 
          ? double.parse(json['distanceMeters']) 
          : (json['distanceMeters'] as num).toDouble(),
      duration: parsedDuration,
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      caloriesBurned: json['caloriesBurned'] ?? 0,
      averageSpeed: (json['averageSpeed'] is String)
          ? double.parse(json['averageSpeed'])
          : (json['averageSpeed'] as num?)?.toDouble() ?? 0.0,
      steps: json['steps'] ?? 0,
      territoriesCaptured: json['territoriesCaptured'] ?? 0,
      pointsEarned: json['pointsEarned'] ?? 0,
      capturedAreaSqMeters: json['capturedAreaSqMeters'] != null
          ? (json['capturedAreaSqMeters'] is String
              ? double.parse(json['capturedAreaSqMeters'])
              : (json['capturedAreaSqMeters'] as num).toDouble())
          : null,
      capturedHexIds: json['capturedHexIds'] != null 
          ? List<String>.from(json['capturedHexIds']) 
          : null,
      routeMapSnapshot: json['routeMapSnapshot'],
    );
  }
}
