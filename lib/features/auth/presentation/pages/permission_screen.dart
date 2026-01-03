import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/patterned_background.dart';
import 'signup_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
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
    
    // Check location permission
    final locationStatus = await Geolocator.checkPermission();
    _locationGranted = locationStatus == LocationPermission.always || 
                       locationStatus == LocationPermission.whileInUse;
    
    // Check activity recognition
    final activityStatus = await Permission.activityRecognition.status;
    _activityRecognitionGranted = activityStatus.isGranted;
    
    // Check notification permission
    final notificationStatus = await Permission.notification.status;
    _notificationGranted = notificationStatus.isGranted;
    
    setState(() => _isChecking = false);
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isChecking = true);
    
    // Request location permission
    if (!_locationGranted) {
      final locationStatus = await Geolocator.requestPermission();
      _locationGranted = locationStatus == LocationPermission.always || 
                         locationStatus == LocationPermission.whileInUse;
    }
    
    // Request activity recognition
    if (!_activityRecognitionGranted) {
      final activityStatus = await Permission.activityRecognition.request();
      _activityRecognitionGranted = activityStatus.isGranted;
    }
    
    // Request notification permission
    if (!_notificationGranted) {
      final notificationStatus = await Permission.notification.request();
      _notificationGranted = notificationStatus.isGranted;
    }
    
    setState(() => _isChecking = false);
    
    // If all granted, proceed
    if (_allPermissionsGranted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignUpScreen()),
      );
    } else {
      _showPermissionDialog();
    }
  }

  bool get _allPermissionsGranted => 
      _locationGranted && _activityRecognitionGranted && _notificationGranted;

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'This app requires all permissions to function properly:\n\n'
          '• Location: Track your movement and capture territories\n'
          '• Physical Activity: Count steps and detect motion\n'
          '• Notifications: Keep you updated on progress\n\n'
          'Please grant all permissions to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
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
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  
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
                
                const SizedBox(height: 48),
                
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
                
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isChecking 
                        ? null 
                        : (_allPermissionsGranted 
                            ? () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                                );
                              }
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
