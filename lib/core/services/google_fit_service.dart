import 'package:health/health.dart';
import 'dart:io' show Platform;

class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final Health _health = Health();
  bool _isAuthorized = false;
  bool _hasReadAccess = false;

  // Health data types we want to access
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
  ];

  // Permissions for each data type
  static final List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static final List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static final List<HealthDataAccess> _readPermissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Check if Health Connect app is installed (Android only)
  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) {
      return true; // iOS uses HealthKit which is built-in
    }

    try {
      await _health.configure();
      // On Android, try to get health connect status
      final status = await _health.getHealthConnectSdkStatus();
      print('🔍 Health Connect SDK Status: $status');

      // If status is available, return true
      if (status != null) {
        if (status ==
            HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          print('⚠️ Health Connect requires provider update');
          return false;
        }
        final isAvailable = status == HealthConnectSdkStatus.sdkAvailable;
        print(isAvailable
            ? '✅ Health Connect app is installed'
            : '❌ Health Connect app not found');
        return isAvailable;
      }

      print('⚠️ Could not determine Health Connect status');
      return false;
    } catch (e) {
      print('❌ Error checking Health Connect installation: $e');
      return false;
    }
  }

  /// Check if Health Connect (or Google Fit) is installed and available
  Future<bool> isHealthConnectAvailable() async {
    // First check if the app is installed
    final installed = await isHealthConnectInstalled();
    if (!installed) {
      print('❌ Health Connect app not installed');
      return false;
    }

    try {
      await _health.configure();
      // Try to check permissions - if this throws an error, Health Connect is not available
      // hasPermissions returning null or false doesn't mean it's not installed
      // It just means permissions haven't been granted yet
      final result = await _health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );

      // If we get here without an exception, Health Connect is available
      print('✅ Health Connect is available (permissions: $result)');
      return true;
    } catch (e) {
      // Exception means Health Connect is not properly set up
      print('❌ Health Connect not available: $e');
      return false;
    }
  }

  /// Get Health Connect SDK status (Android only)
  Future<HealthConnectSdkStatus?> getHealthConnectStatus() async {
    if (!Platform.isAndroid) {
      return HealthConnectSdkStatus.sdkAvailable;
    }
    try {
      await _health.configure();
      return await _health.getHealthConnectSdkStatus();
    } catch (e) {
      print('❌ Error getting Health Connect status: $e');
      return null;
    }
  }

  /// Prompt install/update of Health Connect (Android only)
  Future<void> promptInstallHealthConnect() async {
    if (!Platform.isAndroid) return;
    try {
      await _health.installHealthConnect();
    } catch (e) {
      print('❌ Error launching Health Connect install: $e');
    }
  }

  /// Initialize and request permissions for Google Fit / Health Connect
  Future<bool> initialize() async {
    try {
      await _health.configure();
      print('🏃 Initializing Health Connect...');

      // First check if Health Connect is available
      final available = await isHealthConnectAvailable();
      if (!available) {
        print('❌ Health Connect not available on this device');
        return false;
      }

      print('📱 Requesting Health Connect permissions...');

      // Request authorization - this should open the permission dialog
      final authorized = await _health.requestAuthorization(
        _dataTypes,
        permissions: _permissions,
      );

      print('📋 Authorization result: $authorized');

      _isAuthorized = authorized;
      _hasReadAccess = authorized;

      if (_isAuthorized) {
        print('✅ Health Connect authorized successfully');
      } else {
        print('❌ Health Connect authorization denied or not granted');
      }

      return _isAuthorized;
    } catch (e) {
      print('❌ Error initializing Health Connect: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Check if Health Connect is authorized
  bool get isAuthorized => _isAuthorized;
  bool get hasReadAccess => _hasReadAccess || _isAuthorized;

  /// Check if Health Connect permissions are already granted
  Future<bool> checkAuthorization() async {
    try {
      await _health.configure();
      final result = await _health.hasPermissions(
        _dataTypes,
        permissions: _permissions,
      );
      _isAuthorized = result == true;
      if (_isAuthorized) {
        _hasReadAccess = true;
      }
      return _isAuthorized;
    } catch (e) {
      print('❌ Error checking Health Connect permissions: $e');
      _isAuthorized = false;
      return false;
    }
  }

  /// Check if read permissions are granted for basic stats
  Future<bool> checkReadAuthorization() async {
    try {
      await _health.configure();
      final result = await _health.hasPermissions(
        _readTypes,
        permissions: _readPermissions,
      );
      _hasReadAccess = result == true;
      return _hasReadAccess;
    } catch (e) {
      print('❌ Error checking Health Connect read permissions: $e');
      _hasReadAccess = false;
      return false;
    }
  }

  Future<bool> _ensureReadAccess() async {
    if (hasReadAccess) return true;
    return await checkReadAuthorization();
  }

  /// Check if heart rate read permission is granted
  Future<bool> checkHeartRateAccess() async {
    try {
      await _health.configure();
      final result = await _health.hasPermissions(
        [HealthDataType.HEART_RATE],
        permissions: [HealthDataAccess.READ],
      );
      return result == true;
    } catch (e) {
      print('❌ Error checking heart rate permission: $e');
      return false;
    }
  }

  /// Get steps for today
  Future<int> getTodaySteps() async {
    if (!await _ensureReadAccess()) {
      print('⚠️ Health Connect read access not granted');
      return 0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final stepsFromInterval = await _health.getTotalStepsInInterval(
        startOfDay,
        now,
      );
      if (stepsFromInterval != null) {
        print('📊 Today\'s steps from Health Connect: $stepsFromInterval');
        return stepsFromInterval;
      }

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: now,
      );

      int totalStepsFallback = 0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          totalStepsFallback +=
              (data.value as NumericHealthValue).numericValue.toInt();
        }
      }

      print('📊 Today\'s steps from Google Fit: $totalStepsFallback');
      return totalStepsFallback;
    } catch (e) {
      print('❌ Error getting steps from Google Fit: $e');
      return 0;
    }
  }

  /// Get distance for today (in meters)
  Future<double> getTodayDistance() async {
    if (!await _ensureReadAccess()) {
      print('⚠️ Health Connect read access not granted');
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: startOfDay,
        endTime: now,
      );

      double totalDistance = 0.0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          totalDistance += (data.value as NumericHealthValue).numericValue;
        }
      }

      print('📊 Today\'s distance from Google Fit: ${totalDistance}m');
      return totalDistance;
    } catch (e) {
      print('❌ Error getting distance from Google Fit: $e');
      return 0.0;
    }
  }

  /// Get calories burned for today
  Future<double> getTodayCalories() async {
    if (!await _ensureReadAccess()) {
      print('⚠️ Health Connect read access not granted');
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: now,
      );

      double totalCalories = 0.0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          totalCalories += (data.value as NumericHealthValue).numericValue;
        }
      }

      print('📊 Today\'s calories from Google Fit: $totalCalories');
      return totalCalories;
    } catch (e) {
      print('❌ Error getting calories from Google Fit: $e');
      return 0.0;
    }
  }

  /// Get heart rate data for today
  Future<List<int>> getTodayHeartRate() async {
    if (!await _ensureReadAccess()) {
      print('⚠️ Health Connect read access not granted');
      return [];
    }

    if (!await checkHeartRateAccess()) {
      print('⚠️ Health Connect heart rate permission not granted');
      return [];
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startOfDay,
        endTime: now,
      );

      List<int> heartRates = [];
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          heartRates
              .add((data.value as NumericHealthValue).numericValue.toInt());
        }
      }

      print(
          '📊 Today\'s heart rate readings from Google Fit: ${heartRates.length}');
      return heartRates;
    } catch (e) {
      print('❌ Error getting heart rate from Google Fit: $e');
      return [];
    }
  }

  /// Get heart rate samples for today (with timestamps)
  Future<List<HeartRateSample>> getTodayHeartRateSamples() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return getHeartRateSamplesForRange(
      startDate: startOfDay,
      endDate: now,
    );
  }

  /// Get heart rate samples for a date range (with timestamps)
  Future<List<HeartRateSample>> getHeartRateSamplesForRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!hasReadAccess) {
      print('⚠️ Google Fit not authorized');
      return [];
    }

    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startDate,
        endTime: endDate,
      );

      final samples = <HeartRateSample>[];
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          final value = (data.value as NumericHealthValue).numericValue;
          if (value > 0) {
            samples.add(
              HeartRateSample(
                time: data.dateFrom,
                bpm: value.toInt(),
              ),
            );
          }
        }
      }

      samples.sort((a, b) => a.time.compareTo(b.time));
      return samples;
    } catch (e) {
      print('❌ Error getting heart rate samples: $e');
      return [];
    }
  }

  /// Get health data for a date range
  Future<Map<String, dynamic>> getHealthDataForRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!hasReadAccess) {
      print('⚠️ Google Fit not authorized');
      return {};
    }

    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: startDate,
        endTime: endDate,
      );

      int totalSteps = 0;
      double totalDistance = 0.0;
      double totalCalories = 0.0;
      List<int> heartRates = [];

      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          final value = (data.value as NumericHealthValue).numericValue;

          switch (data.type) {
            case HealthDataType.STEPS:
              totalSteps += value.toInt();
              break;
            case HealthDataType.DISTANCE_DELTA:
              totalDistance += value;
              break;
            case HealthDataType.ACTIVE_ENERGY_BURNED:
              totalCalories += value;
              break;
            case HealthDataType.HEART_RATE:
              heartRates.add(value.toInt());
              break;
            default:
              break;
          }
        }
      }

      return {
        'steps': totalSteps,
        'distance': totalDistance,
        'calories': totalCalories,
        'heartRate': heartRates.isNotEmpty
            ? heartRates.reduce((a, b) => a + b) ~/ heartRates.length
            : 0,
        'heartRateReadings': heartRates.length,
      };
    } catch (e) {
      print('❌ Error getting health data range from Google Fit: $e');
      return {};
    }
  }

  /// Write steps data to Google Fit
  Future<bool> writeSteps(
      int steps, DateTime startTime, DateTime endTime) async {
    if (!_isAuthorized) {
      print('⚠️ Google Fit not authorized');
      return false;
    }

    try {
      final success = await _health.writeHealthData(
        value: steps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: startTime,
        endTime: endTime,
      );

      if (success) {
        print('✅ Wrote $steps steps to Google Fit');
      } else {
        print('❌ Failed to write steps to Google Fit');
      }

      return success;
    } catch (e) {
      print('❌ Error writing steps to Google Fit: $e');
      return false;
    }
  }

  /// Write distance data to Google Fit (in meters)
  Future<bool> writeDistance(
      double meters, DateTime startTime, DateTime endTime) async {
    if (!_isAuthorized) {
      print('⚠️ Google Fit not authorized');
      return false;
    }

    try {
      final success = await _health.writeHealthData(
        value: meters,
        type: HealthDataType.DISTANCE_DELTA,
        startTime: startTime,
        endTime: endTime,
      );

      if (success) {
        print('✅ Wrote ${meters}m distance to Google Fit');
      } else {
        print('❌ Failed to write distance to Google Fit');
      }

      return success;
    } catch (e) {
      print('❌ Error writing distance to Google Fit: $e');
      return false;
    }
  }

  /// Write calories data to Google Fit
  Future<bool> writeCalories(
      double calories, DateTime startTime, DateTime endTime) async {
    if (!_isAuthorized) {
      print('⚠️ Google Fit not authorized');
      return false;
    }

    try {
      final success = await _health.writeHealthData(
        value: calories,
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: startTime,
        endTime: endTime,
      );

      if (success) {
        print('✅ Wrote $calories calories to Google Fit');
      } else {
        print('❌ Failed to write calories to Google Fit');
      }

      return success;
    } catch (e) {
      print('❌ Error writing calories to Google Fit: $e');
      return false;
    }
  }

  /// Write workout/activity data to Google Fit
  Future<bool> writeWorkout({
    required DateTime startTime,
    required DateTime endTime,
    required double distanceMeters,
    required double calories,
    required int steps,
    String activityType = 'RUNNING',
  }) async {
    if (!_isAuthorized) {
      print('⚠️ Google Fit not authorized');
      return false;
    }

    try {
      // Write workout session
      final workoutSuccess = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: startTime,
        end: endTime,
        totalDistance: distanceMeters.toInt(),
        totalEnergyBurned: calories.toInt(),
      );

      if (!workoutSuccess) {
        print('❌ Failed to write workout to Google Fit');
        return false;
      }

      // Write associated data
      await Future.wait([
        writeSteps(steps, startTime, endTime),
        writeDistance(distanceMeters, startTime, endTime),
        writeCalories(calories, startTime, endTime),
      ]);

      print('✅ Wrote complete workout to Google Fit');
      return true;
    } catch (e) {
      print('❌ Error writing workout to Google Fit: $e');
      return false;
    }
  }

  /// Sync activity to Google Fit
  Future<bool> syncActivity({
    required DateTime startTime,
    required DateTime endTime,
    required double distanceMeters,
    required int steps,
    required int caloriesBurned,
  }) async {
    print('🔄 Syncing activity to Google Fit...');
    print('   Steps: $steps');
    print('   Distance: ${distanceMeters}m');
    print('   Calories: $caloriesBurned');

    try {
      final success = await writeWorkout(
        startTime: startTime,
        endTime: endTime,
        distanceMeters: distanceMeters,
        calories: caloriesBurned.toDouble(),
        steps: steps,
      );

      if (success) {
        print('✅ Activity synced to Google Fit successfully');
      } else {
        print('❌ Failed to sync activity to Google Fit');
      }

      return success;
    } catch (e) {
      print('❌ Error syncing activity to Google Fit: $e');
      return false;
    }
  }

  /// Disconnect from Google Fit
  Future<void> disconnect() async {
    try {
      // The health package doesn't have a direct disconnect method
      // User must revoke permissions from system settings
      _isAuthorized = false;
      _hasReadAccess = false;
      print('📴 Google Fit disconnected');
    } catch (e) {
      print('❌ Error disconnecting Google Fit: $e');
    }
  }

  /// Check if device supports Google Fit
  static Future<bool> isSupported() async {
    try {
      // Health package works on Android and iOS
      return true;
    } catch (e) {
      return false;
    }
  }
}

class HeartRateSample {
  final DateTime time;
  final int bpm;

  HeartRateSample({required this.time, required this.bpm});
}
