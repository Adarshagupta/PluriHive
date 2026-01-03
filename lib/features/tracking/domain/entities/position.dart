import 'package:equatable/equatable.dart';

class Position extends Equatable {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;
  
  const Position({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [latitude, longitude, altitude, timestamp];
  
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'timestamp': timestamp.toIso8601String(),
  };
  
  factory Position.fromJson(Map<String, dynamic> json) => Position(
    latitude: json['latitude'],
    longitude: json['longitude'],
    altitude: json['altitude'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}
