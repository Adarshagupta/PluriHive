import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/patterned_background.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/settings_api_service.dart';
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
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update setting'),
          backgroundColor: Colors.red,
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
          backgroundColor: Colors.green,
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
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: PatternedBackground(
        child: CustomScrollView(
          slivers: [
            CommonSliverAppBar(
              title: 'Settings',
              subtitle: 'Manage your preferences',
              iconData: Icons.settings,
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
            subtitle: _selectedBackend == ApiConfig.localUrl ? 'Local (10.1.80.22:3000)' : 'Production (Render)',
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
          _SettingsTile(
            icon: Icons.info,
            title: 'About App',
            subtitle: 'Version 1.0.0',
            onTap: () {},
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
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9D7BEA), Color(0xFF7E5FD8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9D7BEA).withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    context.read<AuthBloc>().add(SignOut());
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    alignment: Alignment.center,
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
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
              subtitle: const Text('http://10.1.80.22:3000'),
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
