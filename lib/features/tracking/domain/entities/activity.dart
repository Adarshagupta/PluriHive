import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'position.dart';

class Activity extends Equatable {
  final String id;
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
  
  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'],
    route: (json['route'] as List).map((p) => Position.fromJson(p)).toList(),
    distanceMeters: json['distanceMeters'],
    duration: Duration(seconds: json['durationSeconds']),
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    caloriesBurned: json['caloriesBurned'],
    averageSpeed: json['averageSpeed'],
    steps: json['steps'] ?? 0,
    territoriesCaptured: json['territoriesCaptured'] ?? 0,
    pointsEarned: json['pointsEarned'] ?? 0,
    capturedAreaSqMeters: json['capturedAreaSqMeters'],
    capturedHexIds: json['capturedHexIds'] != null 
        ? List<String>.from(json['capturedHexIds']) 
        : null,
    routeMapSnapshot: json['routeMapSnapshot'],
  );
}
