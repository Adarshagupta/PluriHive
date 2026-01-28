import 'package:equatable/equatable.dart';

class Position extends Equatable {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final DateTime timestamp;
  
  const Position({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [latitude, longitude, altitude, accuracy, timestamp];
  
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    if (accuracy != null) 'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
  };
  
  factory Position.fromJson(Map<String, dynamic> json) => Position(
    latitude: (json['latitude'] is String) 
        ? double.parse(json['latitude']) 
        : (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] is String) 
        ? double.parse(json['longitude']) 
        : (json['longitude'] as num).toDouble(),
    altitude: json['altitude'] != null
        ? (json['altitude'] is String
            ? double.parse(json['altitude'])
            : (json['altitude'] as num).toDouble())
        : null,
    accuracy: json['accuracy'] != null
        ? (json['accuracy'] is String
            ? double.parse(json['accuracy'])
            : (json['accuracy'] as num).toDouble())
        : null,
    timestamp: DateTime.parse(json['timestamp']),
  );
}
