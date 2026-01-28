import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../../../../core/services/google_fit_service.dart';
import '../../../../core/di/injection_container.dart' as di;

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
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fitness_center,
                color: _isConnected ? const Color(0xFF4CAF50) : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Health Connect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConnected ? 'Connected' : 'Not connected',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isConnected
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade600,
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
                activeColor: const Color(0xFF4CAF50),
              ),
          ],
        ),
      ),
    );
  }
}
