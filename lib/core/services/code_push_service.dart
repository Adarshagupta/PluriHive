import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CodePushService {
  static final CodePushService _instance = CodePushService._internal();
  factory CodePushService() => _instance;
  CodePushService._internal();

  static const String _lastCheckKey = 'last_code_push_check';
  static const Duration _minCheckInterval = Duration(minutes: 30);

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  Future<void> checkForUpdate({
    BuildContext? context,
    bool showNoUpdate = false,
    UpdateTrack? track,
  }) async {
    if (!_updater.isAvailable) {
      if (showNoUpdate && context != null && context.mounted) {
        _showSnack(context, 'Live updates unavailable for this build.');
      }
      return;
    }

    try {
      final status = await _updater.checkForUpdate(track: track);
      switch (status) {
        case UpdateStatus.outdated:
          await _updater.update(track: track);
          if (context != null && context.mounted) {
            _showSnack(
              context,
              'Update downloaded. Restart the app to apply it.',
            );
          }
          break;
        case UpdateStatus.restartRequired:
          if (context != null && context.mounted) {
            _showSnack(context, 'Restart the app to apply the update.');
          }
          break;
        case UpdateStatus.upToDate:
          if (showNoUpdate && context != null && context.mounted) {
            _showSnack(context, 'You are on the latest live update.');
          }
          break;
        case UpdateStatus.unavailable:
          if (showNoUpdate && context != null && context.mounted) {
            _showSnack(context, 'Live updates unavailable for this build.');
          }
          break;
      }
    } on UpdateException catch (e) {
      if (context != null && context.mounted) {
        _showSnack(context, e.message);
      }
    } catch (e) {
      if (context != null && context.mounted) {
        _showSnack(context, 'Live update check failed.');
      }
    }
  }

  Future<void> checkForUpdateIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckMillis = prefs.getInt(_lastCheckKey) ?? 0;
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
    if (DateTime.now().difference(lastCheck) < _minCheckInterval) {
      return;
    }
    await checkForUpdate(context: context);
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> checkForUpdateOnStart(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) {
      await checkForUpdateIfNeeded(context);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
