import 'package:flutter/material.dart';
import '../services/strict_permission_service.dart';
import '../widgets/permission_freeze_overlay.dart';

/// Wrapper widget that ensures permissions are granted before showing child
/// If permissions are revoked, it shows the freeze overlay
class StrictPermissionWrapper extends StatefulWidget {
  final Widget child;
  
  const StrictPermissionWrapper({
    super.key,
    required this.child,
  });

  @override
  State<StrictPermissionWrapper> createState() => _StrictPermissionWrapperState();
}

class _StrictPermissionWrapperState extends State<StrictPermissionWrapper> 
    with WidgetsBindingObserver {
  final _permissionService = StrictPermissionService();
  bool _hasPermissions = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
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
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final granted = await _permissionService.areAllPermissionsGranted();
    setState(() {
      _hasPermissions = granted;
      _isChecking = false;
    });
  }

  void _onPermissionsGranted() {
    setState(() {
      _hasPermissions = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasPermissions) {
      return PermissionFreezeOverlay(
        onPermissionsGranted: _onPermissionsGranted,
      );
    }

    return widget.child;
  }
}
