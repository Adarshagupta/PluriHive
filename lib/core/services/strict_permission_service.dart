import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Strict Permission Monitor Service
/// Continuously monitors all required permissions and freezes app if any are revoked
class StrictPermissionService {
  static final StrictPermissionService _instance = StrictPermissionService._internal();
  factory StrictPermissionService() => _instance;
  StrictPermissionService._internal();

  Timer? _monitoringTimer;
  final Duration _checkInterval = const Duration(seconds: 2);
  
  // Callback when permissions are revoked
  VoidCallback? onPermissionsRevoked;
  
  // Current permission status
  bool _isMonitoring = false;
  bool _allPermissionsGranted = false;

  // Required permissions list
  static const List<ph.Permission> _requiredPermissions = [
    ph.Permission.locationWhenInUse,
    ph.Permission.activityRecognition,
    ph.Permission.notification,
  ];

  // Additional permission for background tracking
  static const ph.Permission _backgroundLocationPermission = ph.Permission.locationAlways;

  /// Start monitoring permissions - Call this after initial permission grant
  void startMonitoring(VoidCallback onRevoked) {
    if (_isMonitoring) return;
    
    onPermissionsRevoked = onRevoked;
    _isMonitoring = true;
    
    debugPrint('🔒 StrictPermissionService: Started monitoring permissions');
    
    _monitoringTimer = Timer.periodic(_checkInterval, (timer) {
      _checkPermissions();
    });
  }

  /// Stop monitoring permissions
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    debugPrint('🔒 StrictPermissionService: Stopped monitoring');
  }

  /// Check all permissions continuously
  Future<void> _checkPermissions() async {
    try {
      final permissionsGranted = await areAllPermissionsGranted();
      
      if (!permissionsGranted && _allPermissionsGranted) {
        // Permissions were granted but now revoked - FREEZE APP
        debugPrint('🚨 StrictPermissionService: PERMISSIONS REVOKED! Freezing app...');
        onPermissionsRevoked?.call();
      }
      
      _allPermissionsGranted = permissionsGranted;
    } catch (e) {
      debugPrint('🔒 StrictPermissionService: Error checking permissions: $e');
    }
  }

  /// Check if all required permissions are granted
  Future<bool> areAllPermissionsGranted() async {
    try {
      // Check location permission
      final locationStatus = await Geolocator.checkPermission();
      final hasLocation = locationStatus == LocationPermission.whileInUse || 
                         locationStatus == LocationPermission.always;
      
      if (!hasLocation) {
        debugPrint('❌ Location permission not granted: $locationStatus');
        return false;
      }

      // Check other permissions
      for (final permission in _requiredPermissions) {
        if (permission == ph.Permission.locationWhenInUse) continue; // Already checked above
        
        final status = await permission.status;
        if (!status.isGranted) {
          debugPrint('❌ Permission not granted: $permission');
          return false;
        }
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services disabled');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('🔒 Error checking permissions: $e');
      return false;
    }
  }

  /// Request all required permissions
  Future<AppPermissionStatus> requestAllPermissions(BuildContext context) async {
    try {
      // Request location permission first
      LocationPermission locationPermission = await Geolocator.checkPermission();
      
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
      
      if (locationPermission == LocationPermission.denied || 
          locationPermission == LocationPermission.deniedForever) {
        return AppPermissionStatus.denied;
      }

      // Request other permissions
      final statuses = await _requiredPermissions.request();
      
      // Check if all granted
      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      if (!allGranted) {
        return AppPermissionStatus.denied;
      }

      // Optionally request background location (for Android 10+)
      if (Platform.isAndroid) {
        final backgroundStatus = await _backgroundLocationPermission.status;
        if (!backgroundStatus.isGranted) {
          await _showBackgroundLocationDialog(context);
        }
      }

      return AppPermissionStatus.granted;
    } catch (e) {
      debugPrint('🔒 Error requesting permissions: $e');
      return AppPermissionStatus.denied;
    }
  }

  Future<void> _showBackgroundLocationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Background Location'),
        content: const Text(
          'To track your territory even when the app is closed, we need "Allow all the time" permission.\n\n'
          'This helps you capture more territory and earn more points!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _backgroundLocationPermission.request();
            },
            child: const Text('Grant'),
          ),
        ],
      ),
    );
  }

  /// Get detailed permission status
  Future<Map<String, bool>> getPermissionDetails() async {
    final locationStatus = await Geolocator.checkPermission();
    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    
    final details = <String, bool>{
      'location_service': locationEnabled,
      'location_permission': locationStatus == LocationPermission.whileInUse || 
                            locationStatus == LocationPermission.always,
      'background_location': locationStatus == LocationPermission.always,
    };

    for (final permission in _requiredPermissions) {
      if (permission == ph.Permission.locationWhenInUse) continue;
      final status = await permission.status;
      details[permission.toString()] = status.isGranted;
    }

    return details;
  }

  /// Open app settings
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }

  bool get isMonitoring => _isMonitoring;
  bool get allPermissionsGranted => _allPermissionsGranted;
}

/// App-specific permission status enum (to avoid conflict with permission_handler)
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}
