import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/patterned_background.dart';
import '../../../../core/services/strict_permission_service.dart';
import '../../../../core/services/pip_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/territory_prefetch_service.dart';
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
  final _pipService = PipService();
  final TerritoryPrefetchService _territoryPrefetchService =
      di.getIt<TerritoryPrefetchService>();
  bool _locationGranted = false;
  bool _activityRecognitionGranted = false;
  bool _notificationGranted = false;
  bool _isChecking = false;
  bool _isInPipMode = false;

  @override
  void initState() {
    super.initState();
    _initializePip();
    _checkAllPermissions();
  }

  @override
  void dispose() {
    _pipService.removePipModeListener(_handlePipModeChange);
    _pipService.disablePip();
    super.dispose();
  }

  Future<void> _initializePip() async {
    await _pipService.initialize();
    await _pipService.enablePipForScreen('permission');
    _pipService.addPipModeListener(_handlePipModeChange);

    final isInPip = await _pipService.isInPipMode();
    if (mounted) {
      setState(() {
        _isInPipMode = isInPip;
      });
    }
  }

  void _handlePipModeChange(bool isInPip, String screen) {
    if (screen == 'permission' && mounted) {
      setState(() {
        _isInPipMode = isInPip;
      });
    }
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

    await _permissionService.requestAllPermissions(context);

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

    // Prefetch nearby territories as soon as permissions are granted.
    _territoryPrefetchService.prefetchAroundUser();

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
    // Show compact PiP view if in PiP mode
    if (_isInPipMode) {
      return _buildPipView();
    }

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
            color: isGranted
                ? Colors.green
                : AppTheme.textSecondary.withOpacity(0.3),
            size: 24,
          ),
        ],
      ),
    );
  }

  /// Compact view for Picture-in-Picture mode
  Widget _buildPipView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Permission icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.security,
                size: 40,
                color: AppTheme.accentColor,
              ),
            ),

            const SizedBox(height: 16),

            // Title
            const Text(
              'Permissions Setup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Status
            Text(
              _allPermissionsGranted ? '✅ All Granted' : '⏳ In Progress',
              style: TextStyle(
                color: _allPermissionsGranted ? Colors.green : Colors.orange,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            // Permission status indicators
            _buildPipPermissionIndicator(
                Icons.location_on, 'Location', _locationGranted),
            const SizedBox(height: 8),
            _buildPipPermissionIndicator(
                Icons.directions_walk, 'Activity', _activityRecognitionGranted),
            const SizedBox(height: 8),
            _buildPipPermissionIndicator(
                Icons.notifications, 'Notifications', _notificationGranted),

            const SizedBox(height: 24),

            // Tap to return hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tap to return to app',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipPermissionIndicator(
      IconData icon, String label, bool granted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: granted ? Colors.green : Colors.white70,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: granted ? Colors.green : Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          granted ? Icons.check_circle : Icons.pending,
          color: granted ? Colors.green : Colors.orange,
          size: 16,
        ),
      ],
    );
  }
}
