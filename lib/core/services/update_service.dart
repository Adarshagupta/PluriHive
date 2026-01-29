import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _lastCheckKey = 'last_update_check';
  static const Duration _minCheckInterval = Duration(hours: 6);
  
  Future<void> checkForUpdate(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      if (Platform.isAndroid) {
        await _checkAndroidUpdate(context, showNoUpdateDialog);
      } else if (Platform.isIOS) {
        await _checkIOSUpdate(context, currentVersion, buildNumber, showNoUpdateDialog);
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      if (showNoUpdateDialog && context.mounted) {
        _showErrorDialog(context, 'Failed to check for updates');
      }
    }
  }

  Future<void> _checkAndroidUpdate(BuildContext context, bool showNoUpdateDialog) async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          // Force update for critical updates
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          // Flexible update for non-critical updates
          await _performFlexibleUpdate(context);
        }
      } else if (showNoUpdateDialog && context.mounted) {
        _showNoUpdateDialog(context);
      }
    } catch (e) {
      debugPrint('Android update check error: $e');
      // Fallback to custom update check
      await _checkCustomUpdate(context, showNoUpdateDialog);
    }
  }

  Future<void> _performFlexibleUpdate(BuildContext context) async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      
      // Listen for download completion
      InAppUpdate.completeFlexibleUpdate().then((_) {
        if (context.mounted) {
          _showUpdateCompletedDialog(context);
        }
      });
    } catch (e) {
      debugPrint('Flexible update error: $e');
    }
  }

  Future<void> _checkIOSUpdate(
    BuildContext context,
    String currentVersion,
    String buildNumber,
    bool showNoUpdateDialog,
  ) async {
    await _checkCustomUpdate(context, showNoUpdateDialog);
  }

  Future<void> checkForUpdateIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckMillis = prefs.getInt(_lastCheckKey) ?? 0;
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
    if (DateTime.now().difference(lastCheck) < _minCheckInterval) {
      return;
    }
    await checkForUpdate(context, showNoUpdateDialog: false);
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Custom update check against your backend
  Future<void> _checkCustomUpdate(BuildContext context, bool showNoUpdateDialog) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final platform = Platform.isAndroid ? 'android' : 'ios';

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/app/version').replace(
          queryParameters: {
            'platform': platform,
            'currentVersion': currentVersion,
            'buildNumber': buildNumber,
          },
        ),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String;
        final downloadUrl = data['download_url'] as String?;
        final minVersion = data['min_version'] as String?;
        final releaseNotes = data['release_notes'] as String? ?? '';
        final isForceUpdate =
            data['force_update'] as bool? ??
            (minVersion != null && _isUpdateAvailable(currentVersion, minVersion));

        if (_isUpdateAvailable(currentVersion, latestVersion)) {
          if (context.mounted) {
            _showUpdateDialog(
              context,
              latestVersion,
              downloadUrl,
              isForceUpdate,
              releaseNotes,
            );
          }
        } else if (showNoUpdateDialog && context.mounted) {
          _showNoUpdateDialog(context);
        }
      }
    } catch (e) {
      debugPrint('Custom update check error: $e');
    }
  }

  bool _isUpdateAvailable(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }

  void _showUpdateDialog(
    BuildContext context,
    String version,
    String? downloadUrl,
    bool isForceUpdate,
    String releaseNotes,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => AlertDialog(
        title: Text(isForceUpdate ? 'Update Required' : 'Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version $version is now available!'),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'What\'s New:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(releaseNotes),
            ],
          ],
        ),
        actions: [
          if (!isForceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (downloadUrl != null) {
                _launchUrl(downloadUrl);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showNoUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Up to Date'),
        content: const Text('You are using the latest version of the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUpdateCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Complete'),
        content: const Text('The app has been updated successfully. Please restart the app.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Optionally restart the app
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Call this on app start to check for updates automatically
  Future<void> checkForUpdateOnStart(BuildContext context) async {
    // Check for updates 3 seconds after app starts
    await Future.delayed(const Duration(seconds: 3));
    if (context.mounted) {
      await checkForUpdateIfNeeded(context);
    }
  }
}
