import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/signin_screen.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/settings_api_service.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/widgets/skeleton.dart';

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
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update setting'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
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
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSettingsSkeleton();
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SignInScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey[200]),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Account Section
            _buildSection(
              title: 'Account',
              children: [
                _buildSettingsTile(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {},
                ),
                _buildSettingsTile(
                  icon: Icons.security_outlined,
                  title: 'Privacy',
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {},
                ),
              ],
            ),

            // Activity Section
            _buildSection(
              title: 'Activity',
              children: [
                _buildSettingsTile(
                  icon: Icons.straighten_outlined,
                  title: 'Units',
                  subtitle: _units == 'metric' ? 'Kilometers, Celsius' : 'Miles, Fahrenheit',
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showUnitsDialog(context),
                ),
                _buildSettingsTile(
                  icon: Icons.gps_fixed_outlined,
                  title: 'GPS Accuracy',
                  subtitle: _gpsAccuracy.toUpperCase(),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showGpsAccuracyDialog(context),
                ),
                _buildSwitchTile(
                  icon: Icons.vibration_outlined,
                  title: 'Haptic Feedback',
                  value: _hapticFeedback,
                  onChanged: (value) {
                    setState(() => _hapticFeedback = value);
                    _updateSetting('hapticFeedback', value);
                  },
                ),
              ],
            ),

            // Notifications Section
            _buildSection(
              title: 'Notifications',
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'Push Notifications',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    _updateSetting('pushNotifications', value);
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.email_outlined,
                  title: 'Email Notifications',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() => _emailNotifications = value);
                    _updateSetting('emailNotifications', value);
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.timeline_outlined,
                  title: 'Streak Reminders',
                  value: _streakReminders,
                  onChanged: (value) {
                    setState(() => _streakReminders = value);
                    _updateSetting('streakReminders', value);
                  },
                ),
              ],
            ),

            // Developer Section
            _buildSection(
              title: 'Developer',
              children: [
                _buildSettingsTile(
                  icon: Icons.developer_mode_outlined,
                  title: 'Backend Server',
                  subtitle: _selectedBackend == ApiConfig.localUrl ? 'Local Development' : 'Production',
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showBackendDialog(context),
                ),
              ],
            ),

            // App Section
            _buildSection(
              title: 'App',
              children: [
                _buildSettingsTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: _language,
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showLanguageDialog(context),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    return _buildSettingsTile(
                      icon: Icons.system_update_outlined,
                      title: 'Check for Updates',
                      subtitle: snapshot.hasData ? 'Version ${snapshot.data!.version}' : 'Loading...',
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: Colors.grey[600]),
                              ),
                            ),
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
                    );
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.storage_outlined,
                  title: 'Storage & Cache',
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {},
                ),
                _buildSettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Sign Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      context.read<AuthBloc>().add(SignOut());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.red[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: _buildChildrenWithDividers(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildrenWithDividers(List<Widget> children) {
    if (children.isEmpty) return [];

    List<Widget> result = [children.first];

    for (int i = 1; i < children.length; i++) {
      result.add(Divider(height: 1, color: Colors.grey[100], indent: 56));
      result.add(children[i]);
    }

    return result;
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: Colors.grey[700]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[900],
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.grey[700]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[900],
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.grey[800],
              inactiveThumbColor: Colors.grey[300],
              inactiveTrackColor: Colors.grey[200],
            ),
          ],
        ),
      ),
    );
  }

  void _showBackendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Select Backend',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('Local Development', style: TextStyle(color: Colors.grey[900])),
                subtitle: Text('10.1.80.11:3000', style: TextStyle(color: Colors.grey[600])),
                value: ApiConfig.localUrl,
                groupValue: _selectedBackend,
                onChanged: (value) {
                  if (value != null) {
                    _changeBackend(value);
                    Navigator.of(context).pop();
                  }
                },
                activeColor: Colors.grey[800],
              ),
              RadioListTile<String>(
                title: Text('Production', style: TextStyle(color: Colors.grey[900])),
                subtitle: Text('Render Deployment', style: TextStyle(color: Colors.grey[600])),
                value: ApiConfig.productionUrl,
                groupValue: _selectedBackend,
                onChanged: (value) {
                  if (value != null) {
                    _changeBackend(value);
                    Navigator.of(context).pop();
                  }
                },
                activeColor: Colors.grey[800],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        );
      },
    );
  }

  void _showUnitsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Units',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('Metric', style: TextStyle(color: Colors.grey[900])),
                subtitle: Text('Kilometers, Celsius', style: TextStyle(color: Colors.grey[600])),
                value: 'metric',
                groupValue: _units,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _units = value);
                    _updateSetting('units', value);
                    Navigator.of(context).pop();
                  }
                },
                activeColor: Colors.grey[800],
              ),
              RadioListTile<String>(
                title: Text('Imperial', style: TextStyle(color: Colors.grey[900])),
                subtitle: Text('Miles, Fahrenheit', style: TextStyle(color: Colors.grey[600])),
                value: 'imperial',
                groupValue: _units,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _units = value);
                    _updateSetting('units', value);
                    Navigator.of(context).pop();
                  }
                },
                activeColor: Colors.grey[800],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        );
      },
    );
  }

  void _showGpsAccuracyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'GPS Accuracy',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('High', style: TextStyle(color: Colors.grey[900])),
                subtitle: Text('Best accuracy, higher battery usage', style: TextStyle(color: Colors.grey[600])),
                value: 'high',
                groupValue: _gpsAccuracy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _gpsAccuracy = value);
                    _updateSetting('gpsAccuracy', value);
                    Navigator.of(context).pop();
                  }
                },
                activeColor: Colors.grey[800],
              ),
              RadioListTile<String>(
                title: Text('Medium', style: TextStyle(color: Colors.grey[900])),
                subtitle: Text('Balanced accuracy and battery', style: TextStyle(color: Colors.grey[600])),
                value: 'medium',
                groupValue: _gpsAccuracy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _gpsAccuracy = value);
                    _updateSetting('gpsAccuracy', value);
                    Navigator.of(context).pop();
                  }
                },
                activeColor: Colors.grey[800],
              ),
              RadioListTile<String>(
                title: Text('Low', style: TextStyle(color: Colors.grey[900])),
                subtitle: Text('Lower accuracy, better battery life', style: TextStyle(color: Colors.grey[600])),
                value: 'low',
                groupValue: _gpsAccuracy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _gpsAccuracy = value);
                    _updateSetting('gpsAccuracy', value);
                    Navigator.of(context).pop();
                  }
                },
                activeColor: Colors.grey[800],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final languages = ['English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese', 'Japanese', 'Korean', 'Chinese'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final language = languages[index];
                    return ListTile(
                      title: Text(
                        language,
                        style: TextStyle(color: Colors.grey[900]),
                      ),
                      trailing: _language == language
                          ? Icon(Icons.check, color: Colors.grey[800])
                          : null,
                      onTap: () {
                        setState(() => _language = language);
                        _updateSetting('language', language);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsSkeleton() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SkeletonShimmer(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              const SkeletonLine(width: 140, height: 20),
              const SizedBox(height: 24),
              SkeletonBox(
                height: 160,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
              SkeletonBox(
                height: 200,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
              SkeletonBox(
                height: 200,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
              SkeletonBox(
                height: 140,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 24),
              SkeletonBox(
                height: 56,
                borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
