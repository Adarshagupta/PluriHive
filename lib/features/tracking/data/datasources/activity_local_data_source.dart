import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/activity.dart';

abstract class ActivityLocalDataSource {
  Future<void> saveActivity(Activity activity);
  Future<List<Activity>> getAllActivities();
  Future<Activity?> getActivity(String id);
  Future<void> deleteActivity(String id);
}

class ActivityLocalDataSourceImpl implements ActivityLocalDataSource {
  static const String _boxName = 'activities';
  
  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }
  
  @override
  Future<void> saveActivity(Activity activity) async {
    final box = await _getBox();
    await box.put(activity.id, activity.toJson());
    print('💾 Activity saved: ${activity.id}');
    print('   Distance: ${(activity.distanceMeters / 1000).toStringAsFixed(2)} km');
    print('   Territories: ${activity.territoriesCaptured}');
    print('   Points: ${activity.pointsEarned}');
  }
  
  @override
  Future<List<Activity>> getAllActivities() async {
    final box = await _getBox();
    final activities = <Activity>[];
    
    for (var key in box.keys) {
      try {
        final json = box.get(key) as Map;
        final activity = Activity.fromJson(Map<String, dynamic>.from(json));
        activities.add(activity);
      } catch (e) {
        print('⚠️ Error loading activity $key: $e');
      }
    }
    
    // Sort by start time (newest first)
    activities.sort((a, b) => b.startTime.compareTo(a.startTime));
    
    print('📚 Loaded ${activities.length} activities from storage');
    return activities;
  }
  
  @override
  Future<Activity?> getActivity(String id) async {
    final box = await _getBox();
    final json = box.get(id);
    
    if (json == null) return null;
    
    try {
      return Activity.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (e) {
      print('⚠️ Error loading activity $id: $e');
      return null;
    }
  }
  
  @override
  Future<void> deleteActivity(String id) async {
    final box = await _getBox();
    await box.delete(id);
    print('🗑️ Activity deleted: $id');
  }
}
