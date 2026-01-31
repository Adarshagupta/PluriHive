import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/google_fit_service.dart';
import '../../../../core/di/injection_container.dart' as di;

const Color _surfaceColor = Color(0xFFF8FEFE);
const Color _borderColor = Color(0xFFCFE8E8);
const Color _iconBadgeColor = Color(0xFFE1F6F6);
const Color _accentColor = Color(0xFF0E9FA0);
const Color _textPrimaryColor = Color(0xFF0B2D30);
const Color _textSecondaryColor = Color(0xFF4A6A6D);
const Color _textTertiaryColor = Color(0xFF6B8B8E);

class GoogleFitCard extends StatefulWidget {
  final EdgeInsetsGeometry margin;

  const GoogleFitCard({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  @override
  State<GoogleFitCard> createState() => _GoogleFitCardState();
}

class _GoogleFitCardState extends State<GoogleFitCard> {
  final GoogleFitService _googleFitService = di.getIt<GoogleFitService>();
  bool _isConnected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await _googleFitService.checkReadAuthorization();
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  Future<void> _connectGoogleFit() async {
    setState(() => _isLoading = true);

    try {
      final status = await _googleFitService.getHealthConnectStatus();
      if (status != null && status != HealthConnectSdkStatus.sdkAvailable) {
        if (mounted) {
          final needsUpdate = status ==
              HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;
          final message = needsUpdate
              ? 'Health Connect needs an update to work. Update it to continue.'
              : 'Health Connect is not installed. Install it to continue.';

          final install = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Health Connect Required'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(needsUpdate ? 'Update' : 'Install'),
                ),
              ],
            ),
          );

          if (install == true) {
            await _googleFitService.promptInstallHealthConnect();
          }
        }
        return;
      }

      final success = await _googleFitService.initialize();

      if (success && mounted) {
        final connected = await _googleFitService.checkReadAuthorization();
        setState(() {
          _isConnected = connected;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to Health Connect!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect. Check if Health Connect is installed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error connecting: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isConnected ? _accentColor : _textTertiaryColor;
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withOpacity(0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected
                    ? _accentColor.withOpacity(0.14)
                    : _iconBadgeColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor.withOpacity(0.8)),
              ),
              child: Icon(
                Icons.fitness_center,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Connect',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConnected ? 'Connected' : 'Not connected',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: _isConnected ? _accentColor : _textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: _isConnected,
                onChanged: (value) {
                  if (value) {
                    _connectGoogleFit();
                  }
                },
                activeColor: _accentColor,
              ),
          ],
        ),
      ),
    );
  }
}
