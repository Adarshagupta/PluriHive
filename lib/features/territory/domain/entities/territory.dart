import 'package:equatable/equatable.dart';

class Territory extends Equatable {
  final String hexId;
  final double centerLat;
  final double centerLng;
  final List<List<double>> boundary;
  final DateTime capturedAt;
  final int points;
  final String? ownerId; // User who owns this territory
  final String? ownerName; // Owner's display name
  final String? name; // Public territory name
  final int captureCount; // How many times it's been captured
  final DateTime? lastBattleAt; // Last time it was contested
  
  const Territory({
    required this.hexId,
    required this.centerLat,
    required this.centerLng,
    required this.boundary,
    required this.capturedAt,
    required this.points,
    this.ownerId,
    this.ownerName,
    this.name,
    this.captureCount = 1,
    this.lastBattleAt,
  });
  
  @override
  List<Object?> get props => [hexId, centerLat, centerLng, boundary, capturedAt, points, ownerId, ownerName, name, captureCount, lastBattleAt];
  
  // Helper: Check if this territory is owned by the current user
  bool isOwnedBy(String userId) => ownerId == userId;
  
  // Helper: Create copy with new owner (for recapture)
  Territory recaptureBy(String newOwnerId, String newOwnerName) {
    return Territory(
      hexId: hexId,
      centerLat: centerLat,
      centerLng: centerLng,
      boundary: boundary,
      capturedAt: DateTime.now(),
      points: points + 25, // Bonus points for recapture
      ownerId: newOwnerId,
      ownerName: newOwnerName,
      name: null,
      captureCount: captureCount + 1,
      lastBattleAt: DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'hexId': hexId,
    'centerLat': centerLat,
    'centerLng': centerLng,
    'boundary': boundary,
    'capturedAt': capturedAt.toIso8601String(),
    'points': points,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'name': name,
    'captureCount': captureCount,
    'lastBattleAt': lastBattleAt?.toIso8601String(),
  };
  
  factory Territory.fromJson(Map<String, dynamic> json) => Territory(
    hexId: json['hexId'],
    centerLat: json['centerLat'],
    centerLng: json['centerLng'],
    boundary: (json['boundary'] as List).map((e) => List<double>.from(e)).toList(),
    capturedAt: DateTime.parse(json['capturedAt']),
    points: json['points'],
    ownerId: json['ownerId'],
    ownerName: json['ownerName'],
    name: json['name'],
    captureCount: json['captureCount'] ?? 1,
    lastBattleAt: json['lastBattleAt'] != null ? DateTime.parse(json['lastBattleAt']) : null,
  );
}
