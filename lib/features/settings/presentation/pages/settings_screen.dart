import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/patterned_background.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/signin_screen.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/settings_api_service.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/di/injection_container.dart' as di;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedBackend = ApiConfig.localUrl;
  late final SettingsApiService _settingsService;
  
  // Settings state
  String _units = 'metric';
  String _gpsAccuracy = 'high';
  bool _hapticFeedback = true;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _streakReminders = true;
  bool _darkMode = false;
  String _language = 'English';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _settingsService = di.getIt<SettingsApiService>();
    _loadBackendPreference();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getSettings();
      setState(() {
        _units = settings['units'] ?? 'metric';
        _gpsAccuracy = settings['gpsAccuracy'] ?? 'high';
        _hapticFeedback = settings['hapticFeedback'] ?? true;
        _pushNotifications = settings['pushNotifications'] ?? true;
        _emailNotifications = settings['emailNotifications'] ?? false;
        _streakReminders = settings['streakReminders'] ?? true;
        _darkMode = settings['darkMode'] ?? false;
        _language = settings['language'] ?? 'English';
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _settingsService.updateSettings({key: value});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Setting updated'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update setting'),
        ),
      );
    }
  }

  Future<void> _loadBackendPreference() async {
    final url = await ApiConfig.getBaseUrl();
    setState(() {
      _selectedBackend = url;
    });
  }

  Future<void> _changeBackend(String newUrl) async {
    await ApiConfig.setBaseUrl(newUrl);
    setState(() {
      _selectedBackend = newUrl;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend changed to: ${newUrl == ApiConfig.localUrl ? "Local" : "Production"}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: PatternedBackground(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Simply pop the current screen
        Navigator.of(context).pop();
        return false; // Prevent default back behavior
      },
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SignInScreen()),
              (route) => false,
            );
          }
        },
        child: Scaffold(
          body: PatternedBackground(
          child: CustomScrollView(
            slivers: [
              CommonSliverAppBar(
                title: 'Settings',
                subtitle: 'Manage your preferences',
                iconData: Icons.settings,
                automaticallyImplyLeading: false,
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
          
          // Account Section
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person,
            title: 'Edit Profile',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.lock,
            title: 'Change Password',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy',
            onTap: () {},
          ),
          
          const Divider(height: 32),
          
          // Activity Section
          _SectionHeader(title: 'Activity'),
          _SettingsTile(
            icon: Icons.straighten,
            title: 'Units',
            subtitle: _units == 'metric' ? 'Metric (km, kg)' : 'Imperial (mi, lb)',
            onTap: () => _showUnitsDialog(context),
          ),
          _SettingsTile(
            icon: Icons.gps_fixed,
            title: 'GPS Accuracy',
            subtitle: _gpsAccuracy == 'high' ? 'High' : _gpsAccuracy == 'medium' ? 'Medium' : 'Low',
            onTap: () => _showGpsAccuracyDialog(context),
          ),
          _SettingsTile(
            icon: Icons.vibration,
            title: 'Haptic Feedback',
            trailing: Switch(
              value: _hapticFeedback,
              onChanged: (value) {
                setState(() => _hapticFeedback = value);
                _updateSetting('hapticFeedback', value);
              },
            ),
          ),
          
          const Divider(height: 32),
          
          // Notifications Section
          _SectionHeader(title: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications,
            title: 'Push Notifications',
            trailing: Switch(
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
                _updateSetting('pushNotifications', value);
              },
            ),
          ),
          _SettingsTile(
            icon: Icons.email,
            title: 'Email Notifications',
            trailing: Switch(
              value: _emailNotifications,
              onChanged: (value) {
                setState(() => _emailNotifications = value);
                _updateSetting('emailNotifications', value);
              },
            ),
          ),
          _SettingsTile(
            icon: Icons.local_fire_department,
            title: 'Streak Reminders',
            trailing: Switch(
              value: _streakReminders,
              onChanged: (value) {
                setState(() => _streakReminders = value);
                _updateSetting('streakReminders', value);
              },
            ),
          ),
          
          const Divider(height: 32),
          
          // Developer Section
          _SectionHeader(title: 'Developer'),
          _SettingsTile(
            icon: Icons.cloud,
            title: 'Backend Server',
            subtitle: _selectedBackend == ApiConfig.localUrl ? 'Local (10.1.80.11:3000)' : 'Production (Render)',
            onTap: () => _showBackendDialog(context),
          ),
          
          const Divider(height: 32),
          
          // App Section
          _SectionHeader(title: 'App'),
          _SettingsTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) {
                setState(() => _darkMode = value);
                _updateSetting('darkMode', value);
              },
            ),
          ),
          _SettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: _language,
            onTap: () => _showLanguageDialog(context),
          ),
          _SettingsTile(
            icon: Icons.download,
            title: 'Download Maps',
            onTap: () {},
          ),
          
          const Divider(height: 32),
          
          // About Section
          _SectionHeader(title: 'About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '1.0.0';
              final buildNumber = snapshot.data?.buildNumber ?? '1';
              return _SettingsTile(
                icon: Icons.info,
                title: 'About App',
                subtitle: 'Version $version ($buildNumber)',
                onTap: () {},
              );
            },
          ),
          _SettingsTile(
            icon: Icons.system_update,
            title: 'Check for Updates',
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              await UpdateService().checkForUpdate(
                context,
                showNoUpdateDialog: true,
              );
              
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          _SettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.policy,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {},
          ),
          
          const SizedBox(height: 24),
          
          // Sign Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                context.read<AuthBloc>().add(SignOut());
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
              ]),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  void _showBackendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Backend Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Local Development'),
              subtitle: const Text('http://10.1.80.11:3000'),
              value: ApiConfig.localUrl,
              groupValue: _selectedBackend,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  _changeBackend(value);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Production (Render)'),
              subtitle: const Text('https://plurihiveapi.onrender.com'),
              value: ApiConfig.productionUrl,
              groupValue: _selectedBackend,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  _changeBackend(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Units',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Metric'),
              subtitle: const Text('Kilometers, Kilograms'),
              value: 'metric',
              groupValue: _units,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  setState(() => _units = value);
                  _updateSetting('units', value);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Imperial'),
              subtitle: const Text('Miles, Pounds'),
              value: 'imperial',
              groupValue: _units,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  setState(() => _units = value);
                  _updateSetting('units', value);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showGpsAccuracyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'GPS Accuracy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('High'),
              subtitle: const Text('Best accuracy, more battery usage'),
              value: 'high',
              groupValue: _gpsAccuracy,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  setState(() => _gpsAccuracy = value);
                  _updateSetting('gpsAccuracy', value);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Medium'),
              subtitle: const Text('Balanced accuracy and battery'),
              value: 'medium',
              groupValue: _gpsAccuracy,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  setState(() => _gpsAccuracy = value);
                  _updateSetting('gpsAccuracy', value);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Low'),
              subtitle: const Text('Lower accuracy, saves battery'),
              value: 'low',
              groupValue: _gpsAccuracy,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  setState(() => _gpsAccuracy = value);
                  _updateSetting('gpsAccuracy', value);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final languages = ['English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese', 'Japanese', 'Korean', 'Chinese'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  return RadioListTile<String>(
                    title: Text(language),
                    value: language,
                    groupValue: _language,
                    onChanged: (value) {
                      if (value != null) {
                        Navigator.pop(context);
                        setState(() => _language = value);
                        _updateSetting('language', value);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textPrimary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
