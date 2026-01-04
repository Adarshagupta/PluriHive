import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _streakReminders = true;
  bool _territoryAlerts = true;
  bool _leaderboardUpdates = false;
  bool _achievementAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // General Notifications
          _buildSectionHeader('General'),
          const SizedBox(height: 12),
          _buildSwitchTile(
            title: 'Push Notifications',
            subtitle: 'Receive push notifications on your device',
            icon: Icons.notifications_active_outlined,
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
            },
          ),
          _buildSwitchTile(
            title: 'Email Notifications',
            subtitle: 'Receive updates via email',
            icon: Icons.email_outlined,
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
            },
          ),
          const SizedBox(height: 32),

          // Activity Notifications
          _buildSectionHeader('Activity'),
          const SizedBox(height: 12),
          _buildSwitchTile(
            title: 'Streak Reminders',
            subtitle: 'Daily reminders to maintain your streak',
            icon: Icons.local_fire_department_outlined,
            value: _streakReminders,
            onChanged: (value) {
              setState(() => _streakReminders = value);
            },
          ),
          _buildSwitchTile(
            title: 'Territory Alerts',
            subtitle: 'Notify when territories are captured or lost',
            icon: Icons.map_outlined,
            value: _territoryAlerts,
            onChanged: (value) {
              setState(() => _territoryAlerts = value);
            },
          ),
          const SizedBox(height: 32),

          // Social Notifications
          _buildSectionHeader('Social'),
          const SizedBox(height: 12),
          _buildSwitchTile(
            title: 'Leaderboard Updates',
            subtitle: 'Notify when your ranking changes',
            icon: Icons.leaderboard_outlined,
            value: _leaderboardUpdates,
            onChanged: (value) {
              setState(() => _leaderboardUpdates = value);
            },
          ),
          _buildSwitchTile(
            title: 'Achievement Alerts',
            subtitle: 'Notify when you earn new achievements',
            icon: Icons.emoji_events_outlined,
            value: _achievementAlerts,
            onChanged: (value) {
              setState(() => _achievementAlerts = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF7FE87A), size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Color(0xFF7FE87A),
          activeTrackColor: Color(0xFF7FE87A).withOpacity(0.5),
        ),
      ),
    );
  }
}
