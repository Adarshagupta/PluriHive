import 'package:equatable/equatable.dart';

class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int targetValue;
  final String category; // distance, territories, streak, level
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int rewardPoints;
  
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.targetValue,
    required this.category,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.rewardPoints,
  });
  
  @override
  List<Object?> get props => [
    id,
    title,
    description,
    iconName,
    targetValue,
    category,
    isUnlocked,
    unlockedAt,
    rewardPoints,
  ];
  
  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      iconName: iconName,
      targetValue: targetValue,
      category: category,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rewardPoints: rewardPoints,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'iconName': iconName,
    'targetValue': targetValue,
    'category': category,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'rewardPoints': rewardPoints,
  };
  
  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    iconName: json['iconName'],
    targetValue: json['targetValue'],
    category: json['category'],
    isUnlocked: json['isUnlocked'] ?? false,
    unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
    rewardPoints: json['rewardPoints'],
  );
  
  static List<Achievement> getDefaultAchievements() {
    return [
      Achievement(
        id: 'first_run',
        title: 'First Steps',
        description: 'Complete your first run',
        iconName: 'directions_run',
        targetValue: 1,
        category: 'distance',
        rewardPoints: 50,
      ),
      Achievement(
        id: '5k_distance',
        title: '5K Runner',
        description: 'Run a total of 5 kilometers',
        iconName: 'flag',
        targetValue: 5,
        category: 'distance',
        rewardPoints: 100,
      ),
      Achievement(
        id: '10k_distance',
        title: '10K Champion',
        description: 'Run a total of 10 kilometers',
        iconName: 'emoji_events',
        targetValue: 10,
        category: 'distance',
        rewardPoints: 200,
      ),
      Achievement(
        id: 'first_territory',
        title: 'Territory Hunter',
        description: 'Capture your first territory',
        iconName: 'map',
        targetValue: 1,
        category: 'territories',
        rewardPoints: 50,
      ),
      Achievement(
        id: '10_territories',
        title: 'Land Baron',
        description: 'Capture 10 territories',
        iconName: 'location_city',
        targetValue: 10,
        category: 'territories',
        rewardPoints: 150,
      ),
      Achievement(
        id: '50_territories',
        title: 'Empire Builder',
        description: 'Capture 50 territories',
        iconName: 'castle',
        targetValue: 50,
        category: 'territories',
        rewardPoints: 500,
      ),
      Achievement(
        id: '7_day_streak',
        title: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        iconName: 'local_fire_department',
        targetValue: 7,
        category: 'streak',
        rewardPoints: 200,
      ),
      Achievement(
        id: 'level_10',
        title: 'Rising Star',
        description: 'Reach level 10',
        iconName: 'stars',
        targetValue: 10,
        category: 'level',
        rewardPoints: 300,
      ),
      Achievement(
        id: '1000_calories',
        title: 'Calorie Crusher',
        description: 'Burn 1000 total calories',
        iconName: 'whatshot',
        targetValue: 1000,
        category: 'calories',
        rewardPoints: 250,
      ),
    ];
  }
}
