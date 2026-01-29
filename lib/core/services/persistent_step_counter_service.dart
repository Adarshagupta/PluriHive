import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PersistentStepCounterService {
  static const String _dailyStepsKey = 'daily_steps';
  static const String _lastResetDateKey = 'last_reset_date';
  static const String _totalCaloriesKey = 'total_calories';
  
  static StreamSubscription<StepCount>? _stepCountStream;
  static int _todaySteps = 0;
  static int _sessionStartSteps = 0;
  static int _lastRecordedSteps = 0;
  static double _todayCalories = 0.0;
  static bool _isInitialized = false;
  
  // Calorie calculation constants
  static const double _caloriesPerStep = 0.04; // Average calories per step
  static const double _userWeightKg = 70.0; // Default weight, should be configurable
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _requestPermissions();
    await _loadTodayData();
    await _startStepCounting();
    _isInitialized = true;
    
    print('✅ Persistent Step Counter initialized: $_todaySteps steps, ${_todayCalories.toStringAsFixed(1)} cal');
  }
  
  static Future<void> _requestPermissions() async {
    // Request activity recognition permission (for step counting)
    var activityStatus = await Permission.activityRecognition.request();
    print('🏃 Activity Recognition: ${activityStatus.isGranted ? "GRANTED" : "DENIED"}');

    if (!activityStatus.isGranted) {
      print('⚠️ Activity Recognition permission denied - step counting may not work');
    }
  }

  static Future<bool> requestBackgroundPermissions() async {
    // Request notification permission (Android 13+)
    var notificationStatus = await Permission.notification.request();
    print('🔔 Notification: ${notificationStatus.isGranted ? "GRANTED" : "DENIED"}');

    if (!notificationStatus.isGranted) {
      return false;
    }

    // Request ignore battery optimization (optional but improves reliability)
    var batteryStatus = await Permission.ignoreBatteryOptimizations.request();
    print('⚡ Battery Optimization: ${batteryStatus.isGranted ? "GRANTED" : "DENIED"}');

    if (!batteryStatus.isGranted) {
      print('⚠️ Battery optimization not disabled - background counting may be unreliable');
    }

    return true;
  }
  
  static Future<void> _loadTodayData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastResetDate = prefs.getString(_lastResetDateKey);
    
    // Reset if it's a new day
    if (lastResetDate != today) {
      await prefs.setString(_lastResetDateKey, today);
      await prefs.setInt(_dailyStepsKey, 0);
      await prefs.setDouble(_totalCaloriesKey, 0.0);
      _todaySteps = 0;
      _todayCalories = 0.0;
      _sessionStartSteps = 0;
      _lastRecordedSteps = 0;
      print('🔄 New day detected - Step counter reset');
    } else {
      _todaySteps = prefs.getInt(_dailyStepsKey) ?? 0;
      _todayCalories = prefs.getDouble(_totalCaloriesKey) ?? 0.0;
      _lastRecordedSteps = _todaySteps;
    }
  }
  
  static Future<void> _startStepCounting() async {
    try {
      print('🔍 Attempting to start step counting...');
      print('🔍 Checking if pedometer sensor is available...');
      
      // Try to get initial step count to test sensor availability
      bool sensorWorking = false;
      
      _stepCountStream = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          if (!sensorWorking) {
            print('✅ Pedometer sensor is working! First event received.');
            sensorWorking = true;
          }
          
          print('👣 Raw step count from sensor: ${event.steps} at ${event.timeStamp}');
          
          // First time receiving data - set baseline
          if (_sessionStartSteps == 0) {
            _sessionStartSteps = event.steps - _todaySteps;
            _lastRecordedSteps = _todaySteps;
            print('🎯 Session baseline set: $_sessionStartSteps | Current steps: $_todaySteps');
          }
          
          // Calculate new steps since session start
          final currentTotalSteps = event.steps - _sessionStartSteps;
          
          print('🔢 Calculation: sensor=${event.steps}, baseline=$_sessionStartSteps, total=$currentTotalSteps, last=$_lastRecordedSteps');
          
          if (currentTotalSteps > _lastRecordedSteps) {
            final stepsDifference = currentTotalSteps - _lastRecordedSteps;
            _todaySteps = currentTotalSteps;
            _lastRecordedSteps = currentTotalSteps;
            
            // Calculate calories
            _todayCalories += stepsDifference * _caloriesPerStep;
            
            // Save to persistent storage
            await _saveTodayData();
            
            // Update notification in real-time - Force update
            FlutterForegroundTask.updateService(
              notificationTitle: '🚶 Step Counter',
              notificationText: '$_todaySteps steps • ${_todayCalories.toStringAsFixed(0)} cal',
            );
            
            print('📊 Steps: $_todaySteps | Calories: ${_todayCalories.toStringAsFixed(1)} | Diff: +$stepsDifference');
            print('📱 Notification updated to: $_todaySteps steps');
          } else {
            print('⏸️ No new steps detected (current: $currentTotalSteps <= last: $_lastRecordedSteps)');
          }
        },
        onError: (error) {
          print('❌ Step counter error: $error');
          print('❌ Error type: ${error.runtimeType}');
          if (error.toString().contains('ACTIVITY_RECOGNITION')) {
            print('❌ ACTIVITY_RECOGNITION permission not granted!');
            print('💡 Go to: Settings → Apps → Plurihive → Permissions → Physical activity → Allow');
          } else if (error.toString().contains('not available')) {
            print('❌ Step counter sensor not available on this device');
          } else {
            print('❌ Unknown error - sensor may not be supported');
          }
        },
        cancelOnError: false,
      );
      
      // Wait 3 seconds to see if we get any data
      await Future.delayed(Duration(seconds: 3));
      if (!sensorWorking) {
        print('⚠️ WARNING: No pedometer events received after 3 seconds!');
        print('💡 Possible issues:');
        print('   1. ACTIVITY_RECOGNITION permission not granted');
        print('   2. Step counter sensor not available on device');
        print('   3. User needs to walk to trigger sensor');
      }
      
      print('✅ Step counting stream listener registered - waiting for step events...');
      print('💡 Walk around to test! If no events appear, check permissions.');
    } catch (e) {
      print('❌ Failed to start step counting: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }
  
  static Future<void> _saveTodayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dailyStepsKey, _todaySteps);
      await prefs.setDouble(_totalCaloriesKey, _todayCalories);
    } catch (e) {
      print('❌ Failed to save step data: $e');
    }
  }
  
  static Future<Map<String, dynamic>> getTodayStats() async {
    await _loadTodayData();
    return {
      'steps': _todaySteps,
      'calories': _todayCalories,
      'distance': _todaySteps * 0.0008, // Average: 0.8m per step = 0.0008km
    };
  }
  
  static int get todaySteps => _todaySteps;
  static double get todayCalories => _todayCalories;
  
  static Future<void> dispose() async {
    await _stepCountStream?.cancel();
    _isInitialized = false;
    print('🛑 Persistent Step Counter disposed');
  }
  
  // Start background service
  static Future<bool> startBackgroundService({bool requestPermissions = true}) async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }
    if (requestPermissions) {
      final ok = await requestBackgroundPermissions();
      if (!ok) return false;
    } else {
      final status = await Permission.notification.status;
      if (!status.isGranted) return false;
    }
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'step_counter_service',
        channelName: 'Step Counter',
        channelDescription: 'Persistent step counter - Running continuously',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.MAX,
        showWhen: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '🚶 Step Counter',
      notificationText: '$_todaySteps steps • ${_todayCalories.toStringAsFixed(0)} cal',
      callback: stepCounterCallback,
    );
    
    print('🔄 Foreground service started - notification cannot be dismissed');
    return true;
  }
  
  static Future<void> updateBackgroundNotification() async {
    if (await FlutterForegroundTask.isRunningService) {
      final currentSteps = _todaySteps;
      final currentCalories = _todayCalories;
      
      await FlutterForegroundTask.updateService(
        notificationTitle: '🚶 Step Counter',
        notificationText: '$currentSteps steps • ${currentCalories.toStringAsFixed(0)} cal',
      );
      
      print('📱 Notification updated: $currentSteps steps, ${currentCalories.toStringAsFixed(0)} cal');
    }
  }
  
  static Future<void> stopBackgroundService() async {
    await FlutterForegroundTask.stopService();
    print('🛑 Background step counter service stopped');
  }
}

// Background callback function
@pragma('vm:entry-point')
void stepCounterCallback() {
  FlutterForegroundTask.setTaskHandler(StepCounterTaskHandler());
}

class StepCounterTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🚀 Step counter background task started');
    // Don't call initialize here - it's already called in main isolate
  }
  
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // This runs in a separate isolate - can't access main isolate variables
    // The notification is updated directly from the pedometer callback
    print('⏰ Background task repeat event (notification already updated from main isolate)');
  }
  
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('💀 Step counter background task destroyed');
  }
  
  @override
  void onNotificationButtonPressed(String id) {}
  
  @override
  void onNotificationPressed() {}
}
