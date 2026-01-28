import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/signin_screen.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/settings_api_service.dart';
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
  bool _darkMode = false;
  String _language = 'English';
  bool _isLoading = true;

  late AnimationController _floatController;
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _settingsService = di.getIt<SettingsApiService>();
    _prefs = di.getIt<SharedPreferences>();
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
    _refreshSettingsFromBackend();
  }

  Future<void> _loadSettingsFromCache() async {
    final cached = _prefs.getString(_settingsCacheKey);
    if (cached == null) {
      if (mounted) setState(() => _isLoading = true);
      return;
    }
    final settings = jsonDecode(cached) as Map<String, dynamic>;
    _applySettings(settings);
    if (mounted) setState(() => _isLoading = false);
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
      _darkMode = settings['darkMode'] ?? false;
      _language = settings['language'] ?? 'English';
      _isLoading = false;
    });
  }

  Future<void> _persistSettingsCache(Map<String, dynamic> settings) async {
    await _prefs.setString(_settingsCacheKey, jsonEncode(settings));
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _isLoading = true);
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
      if (mounted) setState(() => _isLoading = false);
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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1a1a2e),
                Color(0xFF16213e),
                Color(0xFF0f3460),
              ],
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? _buildSettingsSkeleton()
                : CustomScrollView(
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
                              _buildLogoutButton(),
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
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
                    color: const Color(0xFF7FE87A).withOpacity(0.18),
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
                  color: const Color(0xFF1F8EF1).withOpacity(0.15),
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tune your experience and sync preferences.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
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
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
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
                    foregroundColor: const Color(0xFF7FE87A),
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
            ],
          );
        },
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
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign out?',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You will need to sign in again to continue tracking.',
          style: GoogleFonts.dmSans(
            color: Colors.white70,
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

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1F2A44),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
              color: Colors.white,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF7FE87A),
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
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF23324A)),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              dropdownColor: const Color(0xFF111827),
              iconEnabledColor: Colors.white,
              style: GoogleFonts.dmSans(
                color: Colors.white,
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
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF23324A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backend',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch between environments instantly.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withOpacity(0.65),
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
              color: Colors.white.withOpacity(0.5),
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
      selectedColor: const Color(0xFF7FE87A),
      backgroundColor: Colors.white.withOpacity(0.08),
      labelStyle: GoogleFonts.dmSans(
        color: isSelected ? const Color(0xFF0B1C12) : Colors.white,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconBadge(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }

  Widget _buildProfileChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF23324A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: Colors.white.withOpacity(0.65),
          ),
        ),
      ],
    );
  }
}
