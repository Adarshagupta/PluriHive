import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/strict_permission_service.dart';
import 'permission_freeze_overlay.dart';

/// App-wide Permission Gate
/// Blocks ALL screens until permissions are granted
/// Continuously checks and enforces permissions
class PermissionGate extends StatefulWidget {
  final Widget child;
  final bool checkOnInit;
  
  const PermissionGate({
    super.key,
    required this.child,
    this.checkOnInit = true,
  });

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> 
    with WidgetsBindingObserver {
  final _permissionService = StrictPermissionService();
  bool _hasPermissions = false;
  bool _isChecking = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.checkOnInit) {
      _checkPermissionsAndStartMonitoring();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check permissions when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsImmediately();
    }
  }

  Future<void> _checkPermissionsAndStartMonitoring() async {
    await _checkPermissionsImmediately();
    
    if (_hasPermissions && !_permissionService.isMonitoring) {
      // Start monitoring for permission revocations
      _permissionService.startMonitoring(() {
        // Permission revoked - FREEZE!
        if (mounted) {
          setState(() {
            _hasPermissions = false;
          });
        }
      });
    }
  }

  Future<void> _checkPermissionsImmediately() async {
    setState(() => _isChecking = true);
    
    try {
      final granted = await _permissionService.areAllPermissionsGranted();
      
      if (mounted) {
        setState(() {
          _hasPermissions = granted;
          _isChecking = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      if (mounted) {
        setState(() {
          _hasPermissions = false;
          _isChecking = false;
          _isInitialized = true;
        });
      }
    }
  }

  void _onPermissionsGranted() {
    setState(() {
      _hasPermissions = true;
      _isChecking = false;
    });
    
    // Start/restart monitoring
    _permissionService.startMonitoring(() {
      if (mounted) {
        setState(() {
          _hasPermissions = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking
    if (_isChecking && !_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Checking permissions...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Block access if no permissions
    if (!_hasPermissions) {
      return PermissionFreezeOverlay(
        onPermissionsGranted: _onPermissionsGranted,
      );
    }

    // Permissions granted - show app
    return widget.child;
  }
}
