import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetService {
  static const String _distanceKey = 'widget_distance_km';
  static const String _stepsKey = 'widget_steps';
  static const String _progressKey = 'widget_progress';
  static const String _mapSnapshotKey = 'widget_map_snapshot';
  static const String _updatedAtKey = 'widget_updated_at';
  static const String _dailyStepsKey = 'daily_steps';
  static const String _offlineSnapshotKey = 'offline_map_snapshot';

  static Future<void> updateStats({
    required double distanceKm,
    required int steps,
    required int progressPercent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final safeProgress = progressPercent.clamp(0, 100).toString();
    final distanceValue = distanceKm.toStringAsFixed(2);
    final stepsValue = steps.toString();
    final updatedAtValue = DateTime.now().toIso8601String();

    await prefs.setString(_distanceKey, distanceValue);
    await prefs.setString(_stepsKey, stepsValue);
    await prefs.setString(_progressKey, safeProgress);
    await prefs.setString(_updatedAtKey, updatedAtValue);

    await HomeWidget.saveWidgetData(_distanceKey, distanceValue);
    await HomeWidget.saveWidgetData(_stepsKey, stepsValue);
    await HomeWidget.saveWidgetData(_progressKey, safeProgress);
    await HomeWidget.saveWidgetData(_updatedAtKey, updatedAtValue);
    await _refreshWidget();
  }

  static Future<void> updateMapSnapshot(String? base64Snapshot) async {
    if (base64Snapshot == null || base64Snapshot.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapSnapshotKey, base64Snapshot);
    await HomeWidget.saveWidgetData(_mapSnapshotKey, base64Snapshot);
    await _refreshWidget();
  }

  static Future<void> syncFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final steps =
        int.tryParse(prefs.getString(_stepsKey) ?? '') ??
        prefs.getInt(_dailyStepsKey) ??
        0;
    final distanceKm = double.tryParse(prefs.getString(_distanceKey) ?? '') ??
        (steps * 0.0008);
    final progress = int.tryParse(prefs.getString(_progressKey) ?? '') ??
        ((distanceKm / 5.0) * 100).round().clamp(0, 100);
    final updatedAt =
        prefs.getString(_updatedAtKey) ?? DateTime.now().toIso8601String();
    final mapSnapshot =
        prefs.getString(_mapSnapshotKey) ?? prefs.getString(_offlineSnapshotKey);

    await HomeWidget.saveWidgetData(_distanceKey, distanceKm.toStringAsFixed(2));
    await HomeWidget.saveWidgetData(_stepsKey, steps.toString());
    await HomeWidget.saveWidgetData(_progressKey, progress.toString());
    await HomeWidget.saveWidgetData(_updatedAtKey, updatedAt);
    if (mapSnapshot != null && mapSnapshot.isNotEmpty) {
      await HomeWidget.saveWidgetData(_mapSnapshotKey, mapSnapshot);
    }
    await _refreshWidget();
  }

  static Future<void> _refreshWidget() async {
    try {
      await HomeWidget.updateWidget(
        name: 'TerritoryWidgetProvider',
        androidName: 'TerritoryWidgetProvider',
      );
    } catch (_) {}
  }
}
