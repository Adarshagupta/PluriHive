import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../settings/presentation/pages/legal_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
          'Help & Support',
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
          // FAQs Section
          _buildSectionHeader('Frequently Asked Questions'),
          const SizedBox(height: 12),
          _buildFAQItem(
            question: 'How do I capture territories?',
            answer: 'Start a workout session and move around to capture new territories. The app tracks your movement and automatically captures nearby territories as you exercise.',
          ),
          _buildFAQItem(
            question: 'How are points calculated?',
            answer: 'You earn points based on distance traveled, territories captured, and workout duration. The more active you are, the more points you earn!',
          ),
          _buildFAQItem(
            question: 'Can I lose my captured territories?',
            answer: 'Currently, territories remain yours once captured. Multiplayer features with territory competition are coming soon!',
          ),
          _buildFAQItem(
            question: 'How does the leaderboard work?',
            answer: 'The leaderboard ranks users based on total points earned. Compete with others to reach the top!',
          ),
          const SizedBox(height: 32),

          // Contact Section
          _buildSectionHeader('Contact Us'),
          const SizedBox(height: 12),
          _buildContactTile(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'support@territoryfitness.com',
            onTap: () => _launchEmail('support@territoryfitness.com'),
          ),
          _buildContactTile(
            icon: Icons.language,
            title: 'Visit Website',
            subtitle: 'www.territoryfitness.com',
            onTap: () => _launchURL('https://territoryfitness.com'),
          ),
          _buildContactTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Help us improve the app',
            onTap: () => _launchEmail('bugs@territoryfitness.com'),
          ),
          const SizedBox(height: 32),

          // About Section
          _buildSectionHeader('About'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFF7FE87A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.map,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Territory Fitness',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Turn your workouts into an adventure. Capture territories, compete with friends, and explore your city like never before.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Legal Links
          _buildLegalLink('Privacy Policy', () {
            _openLegalDoc(context, LegalDocType.privacy);
          }),
          _buildLegalLink('Terms of Service', () {
            _openLegalDoc(context, LegalDocType.terms);
          }),
          _buildLegalLink('Delete Account', () {
            _openLegalDoc(context, LegalDocType.deleteAccount);
          }),
          _buildLegalLink('Licenses', () {
            showLicensePage(
              context: context,
              applicationName: 'Plurihive',
            );
          }),
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

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        iconColor: Color(0xFF7FE87A),
        collapsedIconColor: Color(0xFF9CA3AF),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLegalLink(String title, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        foregroundColor: Color(0xFF6B7280),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Territory Fitness Support',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _openLegalDoc(BuildContext context, LegalDocType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDetailScreen(type: type),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
