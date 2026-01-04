import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String email;
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? gender;
  final bool hasCompletedOnboarding;
  
  // Stats
  final int totalPoints;
  final int level;
  final double totalDistanceKm;
  final int totalSteps;
  final int totalTerritoriesCaptured;
  final int totalWorkouts;
  
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.weightKg,
    this.heightCm,
    this.age,
    this.gender,
    this.hasCompletedOnboarding = false,
    this.totalPoints = 0,
    this.level = 1,
    this.totalDistanceKm = 0.0,
    this.totalSteps = 0,
    this.totalTerritoriesCaptured = 0,
    this.totalWorkouts = 0,
  });
  
  @override
  List<Object?> get props => [
    id,
    name,
    email,
    weightKg,
    heightCm,
    age,
    gender,
    hasCompletedOnboarding,
    totalPoints,
    level,
    totalDistanceKm,
    totalSteps,
    totalTerritoriesCaptured,
    totalWorkouts,
  ];
  
  User copyWith({
    String? id,
    String? name,
    String? email,
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    bool? hasCompletedOnboarding,
    int? totalPoints,
    int? level,
    double? totalDistanceKm,
    int? totalSteps,
    int? totalTerritoriesCaptured,
    int? totalWorkouts,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalSteps: totalSteps ?? this.totalSteps,
      totalTerritoriesCaptured: totalTerritoriesCaptured ?? this.totalTerritoriesCaptured,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'age': age,
    'gender': gender,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'totalPoints': totalPoints,
    'level': level,
    'totalDistanceKm': totalDistanceKm,
    'totalSteps': totalSteps,
    'totalTerritoriesCaptured': totalTerritoriesCaptured,
    'totalWorkouts': totalWorkouts,
  };
  
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    weightKg: json['weightKg'],
    heightCm: json['heightCm'],
    age: json['age'],
    gender: json['gender'],
    hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
    totalPoints: json['totalPoints'] ?? 0,
    level: json['level'] ?? 1,
    totalDistanceKm: (json['totalDistanceKm'] ?? 0.0).toDouble(),
    totalSteps: json['totalSteps'] ?? 0,
    totalTerritoriesCaptured: json['totalTerritoriesCaptured'] ?? 0,
    totalWorkouts: json['totalWorkouts'] ?? 0,
  );
}
