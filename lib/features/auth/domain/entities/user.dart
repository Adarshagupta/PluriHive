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
  
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.weightKg,
    this.heightCm,
    this.age,
    this.gender,
    this.hasCompletedOnboarding = false,
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
  );
}
