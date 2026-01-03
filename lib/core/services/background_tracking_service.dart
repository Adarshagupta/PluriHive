import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

class BackgroundTrackingService {
  static const String channelId = 'territory_fitness_tracking';
  static const String channelName = 'Territory Tracking';
  
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: channelName,
        channelDescription: 'Active tracking session notification',
        channelImportance: NotificationChannelImportance.LOW, // LOW = silent updates
        priority: NotificationPriority.LOW, // LOW = no pop-up
        onlyAlertOnce: true, // CRITICAL: Don't show new notification on updates
        showWhen: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        playSound: false, // No sound on updates
        enableVibration: false, // No vibration on updates
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(), // No timer - updates on-demand only
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }
  
  static Future<bool> startTracking({
    required double currentDistance,
    required int territoriesCount,
  }) async {
    // Request notification permission first
    if (!await FlutterForegroundTask.isRunningService) {
      final permission = await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
    
    await FlutterForegroundTask.startService(
      serviceId: 512, // Different service ID from step counter (256)
      notificationTitle: '🏃 Active Tracking Session',
      notificationText: 'Distance: ${currentDistance.toStringAsFixed(2)} km • Territories: $territoriesCount',
      callback: startCallback,
    );
    
    print('Foreground service started');
    return true;
  }
  
  static Future<bool> updateNotification({
    required double distance,
    required int territories,
    required String speed,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: '🏃 Active Tracking Session',
      notificationText: '${distance.toStringAsFixed(2)} km • $territories territories • $speed',
    );
    return true;
  }
  
  static Future<bool> stopTracking() async {
    await FlutterForegroundTask.stopService();
    return true;
  }
  
  @pragma('vm:entry-point')
  static void startCallback() {
    FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
  }
}

class TrackingTaskHandler extends TaskHandler {
  int _updateCount = 0;
  
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Background tracking started');
  }
  
  @override
  void onRepeatEvent(DateTime timestamp) async {
    _updateCount++;
    
    // Get location update
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Send data to app
      FlutterForegroundTask.sendDataToMain({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': timestamp.toIso8601String(),
      });
    } catch (e) {
      print('Error getting location in background: $e');
    }
    
    // Update notification every 5 updates (25 seconds)
    if (_updateCount % 5 == 0) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking Active 🏃',
        notificationText: 'Still tracking... Tap to return',
      );
    }
  }
  
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('Background tracking stopped');
  }
  
  @override
  void onNotificationButtonPressed(String id) {
    print('Notification button pressed: $id');
  }
  
  @override
  void onNotificationPressed() {
    // Return to app when notification is tapped
    FlutterForegroundTask.launchApp('/');
  }
}
