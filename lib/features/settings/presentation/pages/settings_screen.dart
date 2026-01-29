import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/signin_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/settings_api_service.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/services/code_push_service.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/services/smart_reminder_service.dart';
import '../../../../core/services/auth_api_service.dart';
import 'legal_screen.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/widgets/skeleton.dart';
import '../../../profile/presentation/pages/personal_info_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  static const String _settingsCacheKey = 'settings_cache_v1';
  static const String _settingsCacheTimeKey = 'settings_cache_time_v1';
  String _selectedBackend = ApiConfig.localUrl;
  late final SettingsApiService _settingsService;
  late final SharedPreferences _prefs;
  bool _isRefreshing = false;

  // Settings state
  String _units = 'metric';
  String _gpsAccuracy = 'high';
  bool _hapticFeedback = true;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _streakReminders = true;
  bool _smartReminders = false;
  String? _smartReminderTime;
  bool _darkMode = false;
  String _language = 'English';
  bool _isInitialLoading = true;
  bool _isSaving = false;
  bool _isDeletingAccount = false;

  late AnimationController _floatController;
  late final Future<PackageInfo> _packageInfoFuture;
  late final TrackingApiService _trackingService;
  late final SmartReminderService _smartReminderService;
  late final AuthApiService _authApiService;
  bool _isSmartReminderUpdating = false;

  @override
  void initState() {
    super.initState();
    _settingsService = di.getIt<SettingsApiService>();
    _prefs = di.getIt<SharedPreferences>();
    _trackingService = di.getIt<TrackingApiService>();
    _smartReminderService = di.getIt<SmartReminderService>();
    _authApiService = di.getIt<AuthApiService>();
    _smartReminderService.initialize();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _packageInfoFuture = PackageInfo.fromPlatform();
    _loadBackendPreference();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _loadSettingsFromCache();
    if (_shouldRefreshSettings()) {
      _refreshSettingsFromBackend();
    }
  }

  Future<void> _loadSettingsFromCache() async {
    final cached = _prefs.getString(_settingsCacheKey);
    if (cached == null) {
      if (mounted) setState(() => _isInitialLoading = false);
      return;
    }
    final settings = jsonDecode(cached) as Map<String, dynamic>;
    _applySettings(settings);
    if (mounted) setState(() => _isInitialLoading = false);
  }

  Future<void> _refreshSettingsFromBackend() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final settings = await _settingsService.getSettings();
      if (mounted) {
        _applySettings(settings);
        await _persistSettingsCache(settings);
      }
    } catch (e) {
      print('Could not load settings from backend: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  void _applySettings(Map<String, dynamic> settings) {
    setState(() {
      _units = settings['units'] ?? 'metric';
      _gpsAccuracy = settings['gpsAccuracy'] ?? 'high';
      _hapticFeedback = settings['hapticFeedback'] ?? true;
      _pushNotifications = settings['pushNotifications'] ?? true;
      _emailNotifications = settings['emailNotifications'] ?? false;
      _streakReminders = settings['streakReminders'] ?? true;
      _smartReminders = settings['smartReminders'] ?? false;
      _smartReminderTime = settings['smartReminderTime'];
      _darkMode = settings['darkMode'] ?? false;
      _language = settings['language'] ?? 'English';
      _isInitialLoading = false;
    });
    _scheduleSmartReminderIfNeeded();
  }

  Future<void> _persistSettingsCache(Map<String, dynamic> settings) async {
    await _prefs.setString(_settingsCacheKey, jsonEncode(settings));
    await _prefs.setInt(
      _settingsCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _shouldRefreshSettings() {
    final last = _prefs.getInt(_settingsCacheTimeKey);
    if (last == null) return true;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(last));
    return age > const Duration(hours: 6);
  }

  Future<void> _updateSetting(
    String key,
    dynamic value, {
    bool showLoading = false,
  }) async {
    if (showLoading) {
      if (mounted) setState(() => _isSaving = true);
    }
    try {
      await _settingsService.updateSettings({key: value});
      final current = jsonDecode(_prefs.getString(_settingsCacheKey) ?? '{}');
      current[key] = value;
      await _persistSettingsCache(current);
      _applySettings(current);
    } catch (e) {
      print('Failed to update setting $key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update setting')),
        );
      }
    } finally {
      if (mounted && showLoading) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadBackendPreference() async {
    final saved = await ApiConfig.getBaseUrl();
    if (!mounted) return;
    setState(() => _selectedBackend = saved);
  }

  Future<void> _changeBackend(String url) async {
    setState(() => _selectedBackend = url);
    await ApiConfig.setBaseUrl(url);
  }

  Future<void> _toggleSmartReminders(bool value) async {
    await _updateSetting('smartReminders', value, showLoading: false);
    if (!value) {
      await _smartReminderService.cancelDailyReminder();
      return;
    }
    await _refreshSmartReminderTime();
  }

  Future<void> _refreshSmartReminderTime() async {
    if (_isSmartReminderUpdating) return;
    _isSmartReminderUpdating = true;
    try {
      final activities = await _trackingService.getUserActivities(limit: 30);
      final times = <DateTime>[];
      for (final activity in activities) {
        final raw = activity['startTime'] ?? activity['createdAt'];
        if (raw is String) {
          final parsed = DateTime.tryParse(raw);
          if (parsed != null) {
            times.add(parsed.toLocal());
          }
        }
      }
      final computed = _smartReminderService.computeTypicalTime(times);
      final formatted = _smartReminderService.formatTime(computed);
      await _updateSetting('smartReminderTime', formatted, showLoading: false);
      if (mounted) {
        setState(() => _smartReminderTime = formatted);
      }
      await _smartReminderService.scheduleDaily(computed);
    } catch (e) {
      print('Failed to refresh smart reminder time: $e');
    } finally {
      _isSmartReminderUpdating = false;
    }
  }

  void _scheduleSmartReminderIfNeeded() {
    if (!_smartReminders) return;
    final time = _smartReminderService.parseTime(_smartReminderTime) ??
        const TimeOfDay(hour: 19, minute: 0);
    _smartReminderService.scheduleDaily(time);
  }

  String _smartReminderSubtitle() {
    final time = _smartReminderService.parseTime(_smartReminderTime);
    if (_smartReminders && time != null) {
      return 'We will remind you around ${time.format(context)}.';
    }
    return 'We learn your usual activity time and remind you.';
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFFF7F7F2),
        body: SafeArea(
          child: _isInitialLoading
              ? _buildSettingsSkeleton()
              : Stack(
                  children: [
                    CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _buildHeader(),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                _buildProfileSection(),
                                const SizedBox(height: 32),
                                _buildActivitySection(),
                                const SizedBox(height: 32),
                                _buildNotificationSection(),
                                const SizedBox(height: 32),
                                _buildPreferencesSection(),
                                const SizedBox(height: 32),
                                _buildAboutSection(),
                                const SizedBox(height: 40),
                                _buildDangerZoneSection(),
                                const SizedBox(height: 24),
                                _buildLogoutButton(),
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isSaving || _isRefreshing)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSettingsSkeleton() {
    return SkeletonShimmer(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          const SizedBox(height: 12),
          const SkeletonLine(height: 24, width: 160),
          const SizedBox(height: 8),
          const SkeletonLine(height: 14, width: 220),
          const SizedBox(height: 24),
          SkeletonBox(
            height: 110,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 20),
          SkeletonBox(
            height: 160,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 20),
          SkeletonBox(
            height: 180,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 20),
          SkeletonBox(
            height: 180,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 20),
          SkeletonBox(
            height: 140,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor: const Color(0xFFF7F7F2),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          children: [
            Positioned(
              right: -40,
              top: -10,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  final dy = (_floatController.value - 0.5) * 18;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: 10,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFBFD9FF).withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tune your experience and sync preferences.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return _buildSectionCard(
            title: 'Profile',
            child: _buildEmptyState(
              title: 'Sign in to see your profile',
              subtitle: 'We will keep your profile synced across devices.',
              icon: Icons.account_circle_outlined,
            ),
          );
        }

        final user = state.user;
        return _buildSectionCard(
          title: 'Profile',
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildProfileChip(
                    icon: Icons.monitor_weight_outlined,
                    label: user.weightKg != null
                        ? '${user.weightKg!.toStringAsFixed(1)} kg'
                        : 'Weight not set',
                  ),
                  _buildProfileChip(
                    icon: Icons.height,
                    label: user.heightCm != null
                        ? '${user.heightCm!.toStringAsFixed(0)} cm'
                        : 'Height not set',
                  ),
                  _buildProfileChip(
                    icon: Icons.flag_outlined,
                    label: user.country?.isNotEmpty == true
                        ? user.country!
                        : 'Country not set',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PersonalInfoScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivitySection() {
    return _buildSectionCard(
      title: 'Activity',
      child: Column(
        children: [
          _buildDropdownTile(
            icon: Icons.straighten,
            title: 'Units',
            subtitle: 'Distance and elevation units',
            value: _units,
            options: const ['metric', 'imperial'],
            onChanged: (value) => _updateSetting('units', value),
            formatLabel: (value) => value == 'imperial' ? 'Imperial' : 'Metric',
          ),
          const SizedBox(height: 12),
          _buildDropdownTile(
            icon: Icons.gps_fixed,
            title: 'GPS accuracy',
            subtitle: 'Battery vs precision tradeoff',
            value: _gpsAccuracy,
            options: const ['low', 'balanced', 'high'],
            onChanged: (value) => _updateSetting('gpsAccuracy', value),
            formatLabel: (value) {
              switch (value) {
                case 'low':
                  return 'Low (battery saver)';
                case 'balanced':
                  return 'Balanced';
                default:
                  return 'High precision';
              }
            },
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.vibration,
            title: 'Haptic feedback',
            subtitle: 'Tactile cues during tracking',
            value: _hapticFeedback,
            onChanged: (value) => _updateSetting('hapticFeedback', value),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return _buildSectionCard(
      title: 'Notifications',
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push notifications',
            subtitle: 'Session summaries and milestones',
            value: _pushNotifications,
            onChanged: (value) => _updateSetting('pushNotifications', value),
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.email_outlined,
            title: 'Email updates',
            subtitle: 'News and weekly highlights',
            value: _emailNotifications,
            onChanged: (value) => _updateSetting('emailNotifications', value),
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.local_fire_department_outlined,
            title: 'Streak reminders',
            subtitle: 'Nudges to keep your streak alive',
            value: _streakReminders,
            onChanged: (value) => _updateSetting('streakReminders', value),
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.schedule_outlined,
            title: 'Smart reminders',
            subtitle: _smartReminderSubtitle(),
            value: _smartReminders,
            onChanged: (value) => _toggleSmartReminders(value),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return _buildSectionCard(
      title: 'Preferences',
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark mode',
            subtitle: 'Darker palette for low light',
            value: _darkMode,
            onChanged: (value) => _updateSetting('darkMode', value),
          ),
          const SizedBox(height: 12),
          _buildDropdownTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'Interface language',
            value: _language,
            options: const ['English', 'Spanish', 'French'],
            onChanged: (value) => _updateSetting('language', value),
          ),
          const SizedBox(height: 12),
          _buildBackendSection(),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return _buildSectionCard(
      title: 'About',
      child: FutureBuilder<PackageInfo>(
        future: _packageInfoFuture,
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '--';
          final buildNumber = snapshot.data?.buildNumber ?? '--';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                icon: Icons.info_outline,
                label: 'Version',
                value: '$version ($buildNumber)',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.shield_outlined,
                label: 'Privacy',
                value: 'Your activity data stays encrypted in transit.',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.help_outline,
                label: 'Support',
                value: 'help@territory.fitness',
              ),
              const SizedBox(height: 16),
              _buildActionRow(
                icon: Icons.policy_outlined,
                label: 'Legal & privacy',
                value: 'Privacy policy, terms, account deletion',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await CodePushService().checkForUpdate(
                      context: context,
                      showNoUpdate: true,
                    );
                    if (context.mounted) {
                      UpdateService().checkForUpdate(
                        context,
                        showNoUpdateDialog: true,
                      );
                    }
                  },
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text('Check for updates'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDangerZoneSection() {
    return _buildSectionCard(
      title: 'Danger zone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete your account and all stored activity data.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isDeletingAccount ? null : _confirmDeleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isDeletingAccount
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Delete account',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _confirmLogout,
        style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Sign out',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign out?',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You will need to sign in again to continue tracking.',
          style: GoogleFonts.dmSans(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      context.read<AuthBloc>().add(SignOut());
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete account?',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This permanently deletes your account and all activity data. '
          'This cannot be undone.',
          style: GoogleFonts.dmSans(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        setState(() => _isDeletingAccount = true);
        await _authApiService.deleteAccount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeletingAccount = false);
          context.read<AuthBloc>().add(SignOut());
        }
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        _buildIconBadge(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    String Function(String value)? formatLabel,
  }) {
    final labelFor = formatLabel ?? (value) => value;
    final safeValue = options.contains(value) ? value : options.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _buildIconBadge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              dropdownColor: Colors.white,
              iconEnabledColor: AppTheme.textPrimary,
              style: GoogleFonts.dmSans(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              items: options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(labelFor(option)),
                    ),
                  )
                  .toList(),
              onChanged: (selected) {
                if (selected != null) {
                  onChanged(selected);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backend',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch between environments instantly.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildBackendChip('Local', ApiConfig.localUrl),
              _buildBackendChip('Production', ApiConfig.productionUrl),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedBackend,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendChip(String label, String value) {
    final isSelected = _selectedBackend == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeBackend(value),
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      labelStyle: GoogleFonts.dmSans(
        color: isSelected ? const Color(0xFF0B1C12) : AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconBadge(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBadge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildIconBadge(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: AppTheme.accentColor),
    );
  }

  Widget _buildProfileChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconBadge(icon),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
