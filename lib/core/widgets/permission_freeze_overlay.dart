import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/strict_permission_service.dart';

/// Permission Freeze Overlay
/// Displays a calm, minimal blocking overlay when permissions are revoked
/// User must grant permissions to continue
class PermissionFreezeOverlay extends StatefulWidget {
  final VoidCallback onPermissionsGranted;
  
  const PermissionFreezeOverlay({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionFreezeOverlay> createState() => _PermissionFreezeOverlayState();
}

class _PermissionFreezeOverlayState extends State<PermissionFreezeOverlay> {
  final _permissionService = StrictPermissionService();
  bool _isCheckingPermissions = false;
  Map<String, bool> _permissionDetails = {};

  @override
  void initState() {
    super.initState();
    _loadPermissionDetails();
  }

  Future<void> _loadPermissionDetails() async {
    final details = await _permissionService.getPermissionDetails();
    if (mounted) {
      setState(() {
        _permissionDetails = details;
      });
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    setState(() => _isCheckingPermissions = true);
    
    try {
      final granted = await _permissionService.areAllPermissionsGranted();
      
      if (granted) {
        widget.onPermissionsGranted();
      } else {
        await _permissionService.openSettings();
        
        await Future.delayed(const Duration(seconds: 2));
        final stillGranted = await _permissionService.areAllPermissionsGranted();
        
        if (stillGranted) {
          widget.onPermissionsGranted();
        } else {
          await _loadPermissionDetails();
        }
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingPermissions = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7FE87A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Color(0xFF7FE87A),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Permissions Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                const Text(
                  'Plurihive needs a few permissions to help you track your activities and capture territories',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Permission cards
                _buildPermissionCard(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  description: 'Track your routes',
                  isGranted: _permissionDetails['location_permission'] ?? false,
                ),
                
                const SizedBox(height: 12),
                
                _buildPermissionCard(
                  icon: Icons.directions_walk_outlined,
                  title: 'Physical Activity',
                  description: 'Count your steps',
                  isGranted: _permissionDetails['Permission.activityRecognition'] ?? false,
                ),
                
                const SizedBox(height: 12),
                
                _buildPermissionCard(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  description: 'Stay updated',
                  isGranted: _permissionDetails['Permission.notification'] ?? false,
                ),
                
                const Spacer(),
                
                // Grant button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isCheckingPermissions ? null : _checkAndRequestPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7FE87A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: const Color(0xFF7FE87A).withOpacity(0.5),
                    ),
                    child: _isCheckingPermissions
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Grant Permissions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Exit button
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Exit App'),
                        content: const Text(
                          'Permissions are required to use this app. Are you sure you want to exit?',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              SystemNavigator.pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Exit'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'Exit App',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted 
              ? const Color(0xFF7FE87A).withOpacity(0.3)
              : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGranted 
                  ? const Color(0xFF7FE87A).withOpacity(0.1)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isGranted 
                  ? const Color(0xFF7FE87A)
                  : const Color(0xFF9CA3AF),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.circle_outlined,
            color: isGranted 
                ? const Color(0xFF7FE87A)
                : const Color(0xFFD1D5DB),
            size: 22,
          ),
        ],
      ),
    );
  }
}
