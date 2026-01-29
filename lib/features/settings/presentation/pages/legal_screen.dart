import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/legal_api_service.dart';
import '../../../../core/theme/app_theme.dart';

enum LegalDocType { privacy, terms, deleteAccount, dataUsage }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.initialDoc});

  final LegalDocType? initialDoc;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initialDoc != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LegalDetailScreen(type: initialDoc!),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Legal & Privacy',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildCard(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we collect and use your data',
            onTap: () => _open(context, LegalDocType.privacy),
          ),
          _buildCard(
            context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Rules for using Plurihive',
            onTap: () => _open(context, LegalDocType.terms),
          ),
          _buildCard(
            context,
            icon: Icons.storage_outlined,
            title: 'Data Usage',
            subtitle: 'Summary of data usage and permissions',
            onTap: () => _open(context, LegalDocType.dataUsage),
          ),
          _buildCard(
            context,
            icon: Icons.person_remove_outlined,
            title: 'Delete Account',
            subtitle: 'How to delete your account',
            onTap: () => _open(context, LegalDocType.deleteAccount),
          ),
          _buildCard(
            context,
            icon: Icons.article_outlined,
            title: 'Open Source Licenses',
            subtitle: 'Libraries used in the app',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Plurihive',
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, LegalDocType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDetailScreen(type: type),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.accentColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}

class LegalDetailScreen extends StatefulWidget {
  const LegalDetailScreen({super.key, required this.type});

  final LegalDocType type;

  @override
  State<LegalDetailScreen> createState() => _LegalDetailScreenState();
}

class _LegalDetailScreenState extends State<LegalDetailScreen> {
  late final LegalApiService _legalApiService;

  @override
  void initState() {
    super.initState();
    _legalApiService = di.getIt<LegalApiService>();
  }

  Future<Map<String, dynamic>> _loadDoc() {
    switch (widget.type) {
      case LegalDocType.privacy:
        return _legalApiService.getPrivacyPolicy();
      case LegalDocType.terms:
        return _legalApiService.getTerms();
      case LegalDocType.deleteAccount:
        return _legalApiService.getDeleteAccount();
      case LegalDocType.dataUsage:
      default:
        return _legalApiService.getDataUsage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _titleFor(widget.type),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDoc(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildError();
          }
          final doc = snapshot.data!;
          final updatedAt = doc['updatedAt']?.toString() ?? '';
          final body = doc['body']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                doc['title']?.toString() ?? _titleFor(widget.type),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (updatedAt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Last updated: $updatedAt',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              'Could not load document',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(LegalDocType type) {
    switch (type) {
      case LegalDocType.privacy:
        return 'Privacy Policy';
      case LegalDocType.terms:
        return 'Terms of Service';
      case LegalDocType.deleteAccount:
        return 'Delete Account';
      case LegalDocType.dataUsage:
      default:
        return 'Data Usage';
    }
  }
}
