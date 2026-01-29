import 'dart:async';
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
  ];


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
  Future<AppPermissionStatus> requestAllPermissions() async {
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

      return AppPermissionStatus.granted;
    } catch (e) {
      debugPrint('🔒 Error requesting permissions: $e');
      return AppPermissionStatus.denied;
    }
  }

  // Background location is not required for foreground tracking sessions.

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

    final notificationStatus = await ph.Permission.notification.status;
    details['Permission.notification'] = notificationStatus.isGranted;

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
