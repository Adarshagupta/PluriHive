import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_constants.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/patterned_background.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            subtitle: 'Metric (km, kg)',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.gps_fixed,
            title: 'GPS Accuracy',
            subtitle: 'High',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.vibration,
            title: 'Haptic Feedback',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),
          
          const Divider(height: 32),
          
          // Notifications Section
          _SectionHeader(title: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications,
            title: 'Push Notifications',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),
          _SettingsTile(
            icon: Icons.email,
            title: 'Email Notifications',
            trailing: Switch(
              value: false,
              onChanged: (value) {},
            ),
          ),
          _SettingsTile(
            icon: Icons.local_fire_department,
            title: 'Streak Reminders',
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),
          
          const Divider(height: 32),
          
          // App Section
          _SectionHeader(title: 'App'),
          _SettingsTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            trailing: Switch(
              value: false,
              onChanged: (value) {},
            ),
          ),
          _SettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            onTap: () {},
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
