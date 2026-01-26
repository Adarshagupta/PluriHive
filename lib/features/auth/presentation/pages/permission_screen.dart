import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/patterned_background.dart';
import '../../../../core/services/strict_permission_service.dart';
import '../bloc/auth_bloc.dart';
import 'profile_setup_screen.dart';
import 'signup_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final _permissionService = StrictPermissionService();
  bool _locationGranted = false;
  bool _activityRecognitionGranted = false;
  bool _notificationGranted = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isChecking = true);
    
    final granted = await _permissionService.areAllPermissionsGranted();
    
    if (granted) {
      // All permissions already granted - proceed
      _navigateToNextScreen();
      return;
    }
    
    // Check individual permissions for display
    final locationStatus = await Geolocator.checkPermission();
    _locationGranted = locationStatus == LocationPermission.always || 
                       locationStatus == LocationPermission.whileInUse;
    
    final activityStatus = await Permission.activityRecognition.status;
    _activityRecognitionGranted = activityStatus.isGranted;
    
    final notificationStatus = await Permission.notification.status;
    _notificationGranted = notificationStatus.isGranted;
    
    setState(() => _isChecking = false);
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isChecking = true);
    
    final status = await _permissionService.requestAllPermissions(context);
    
    // Check again after request
    await _checkAllPermissions();
    
    setState(() => _isChecking = false);
    
    if (_allPermissionsGranted) {
      _navigateToNextScreen();
    } else {
      _showPermissionDialog();
    }
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    
    final authState = context.read<AuthBloc>().state;
    
    if (authState is Authenticated) {
      // Navigate to Profile Setup where they add their details (weight, height, age, gender)
      // Profile Setup will dispatch CompleteOnboarding when done
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignUpScreen()),
      );
    }
  }

  bool get _allPermissionsGranted => 
      _locationGranted && _activityRecognitionGranted && _notificationGranted;

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss
      builder: (context) => PopScope(
        canPop: false, // Cannot go back
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red),
              SizedBox(width: 8),
              Text('Permissions Required'),
            ],
          ),
          content: const Text(
            '⚠️ This app REQUIRES all permissions to function:\n\n'
            '• Location: Track your movement and capture territories\n'
            '• Physical Activity: Count steps and detect motion\n'
            '• Notifications: Keep you updated on progress\n\n'
            '❌ Without these permissions, the app CANNOT work.\n\n'
            'Please grant ALL permissions to continue.',
            style: TextStyle(fontSize: 12),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _permissionService.openSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security,
                      size: 60,
                      color: AppTheme.accentColor,
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Grant Permissions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'We need your permission to make the app work properly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Permission items
                _buildPermissionItem(
                  icon: Icons.location_on,
                  title: 'Location',
                  description: 'Track your movement and capture territories',
                  isGranted: _locationGranted,
                ),
                
                const SizedBox(height: 16),
                
                _buildPermissionItem(
                  icon: Icons.directions_walk,
                  title: 'Physical Activity',
                  description: 'Count steps and detect motion',
                  isGranted: _activityRecognitionGranted,
                ),
                
                const SizedBox(height: 16),
                
                _buildPermissionItem(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  description: 'Keep you updated on progress',
                  isGranted: _notificationGranted,
                ),
                
                const SizedBox(height: 40),
                
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isChecking 
                        ? null 
                        : (_allPermissionsGranted 
                            ? _navigateToNextScreen
                            : _requestAllPermissions),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allPermissionsGranted 
                          ? Colors.green 
                          : AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _allPermissionsGranted 
                                ? 'Continue' 
                                : 'Grant Permissions',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted 
                  ? Colors.green.withOpacity(0.1) 
                  : AppTheme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isGranted ? Colors.green : AppTheme.accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.circle_outlined,
            color: isGranted ? Colors.green : AppTheme.textSecondary.withOpacity(0.3),
            size: 24,
          ),
        ],
      ),
    );
  }
}
