import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'persistent_step_counter_service.dart';

class UserDataCleanupService {
  static const List<String> _hiveBoxes = [
    'activities',
    'pending_sync',
  ];

  static const List<String> _prefKeys = [
    // Auth/local user
    'current_user',
    'auth_token',
    'user_id',

    // User stats + territory data
    'user_stats',
    'captured_territories',

    // Territory caches
    'territory_cache_all',
    'territory_cache_boss',

    // UI caches
    'profile_stats_cache_v1',
    'leaderboard_cache_v1',
    'leaderboard_cache_v2',
    'settings_cache_v1',

    // Route caches
    'routes_saved_cache_v1',
    'routes_popular_cache_last_v1',

    // Step counter
    'daily_steps',
    'last_reset_date',
    'total_calories',

    // Home widget
    'widget_distance_km',
    'widget_steps',
    'widget_progress',
    'widget_updated_at',
    'widget_map_snapshot',
    'offline_map_snapshot',
  ];

  static const List<String> _cachePrefKeys = [
    // Territory caches
    'territory_cache_all',
    'territory_cache_boss',
    'territory_cache_nearby',

    // UI caches
    'profile_stats_cache_v1',
    'leaderboard_cache_v1',
    'leaderboard_cache_v2',
    'settings_cache_v1',
    'settings_cache_time_v1',

    // Route caches
    'routes_saved_cache_v1',
    'routes_popular_cache_last_v1',

    // Home widget / snapshots
    'widget_map_snapshot',
    'offline_map_snapshot',
  ];

  static Future<void> clearCacheOnly() async {
    await clearLiteCache();
  }

  static Future<void> clearLiteCache({bool clearActivities = false}) async {
    // Clear SharedPreferences caches.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _cachePrefKeys) {
        await prefs.remove(key);
      }

      // Remove dynamic route/leaderboard caches.
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('routes_popular_cache_v1_')) {
          await prefs.remove(key);
        }
        if (key.startsWith('leaderboard_cache_v2:')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('[cleanup] SharedPreferences cache cleanup failed: $e');
    }

    // Clear cached network images (disk).
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      print('[cleanup] Image cache cleanup failed: $e');
    }

    // Clear in-memory image cache.
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      print('[cleanup] In-memory image cache cleanup failed: $e');
    }

    // Strip route snapshots from local activity caches.
    await _stripRouteSnapshotsFromBox('activities');
    await _stripRouteSnapshotsFromBox('pending_sync', nestedPayload: true);

    if (clearActivities) {
      await _clearHiveBox('activities');
      await _clearHiveBox('pending_sync');
    }

    // Clear temporary files (safe to recreate).
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('[cleanup] Temp directory cleanup failed: $e');
    }
  }

  static Future<void> _stripRouteSnapshotsFromBox(
    String boxName, {
    bool nestedPayload = false,
  }) async {
    try {
      Box box;
      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box(boxName);
      } else {
        final exists = await Hive.boxExists(boxName);
        if (!exists) return;
        box = await Hive.openBox(boxName);
      }

      final keys = List<dynamic>.from(box.keys);
      for (final key in keys) {
        final raw = box.get(key);
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        bool updated = false;

        if (nestedPayload) {
          final payload = data['payload'];
          if (payload is Map && payload.containsKey('routeMapSnapshot')) {
            final payloadMap = Map<String, dynamic>.from(payload);
            payloadMap.remove('routeMapSnapshot');
            data['payload'] = payloadMap;
            updated = true;
          }
        } else if (data.containsKey('routeMapSnapshot')) {
          data.remove('routeMapSnapshot');
          updated = true;
        }

        if (updated) {
          await box.put(key, data);
        }
      }

      if (!Hive.isBoxOpen(boxName)) {
        await box.close();
      }
    } catch (e) {
      print('[cleanup] Route snapshot cleanup failed for $boxName: $e');
    }
  }

  static Future<void> _clearHiveBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
        return;
      }
      final exists = await Hive.boxExists(boxName);
      if (!exists) return;
      final box = await Hive.openBox(boxName);
      await box.clear();
      await box.close();
    } catch (e) {
      print('[cleanup] Hive box cleanup failed for $boxName: $e');
    }
  }

  static Future<void> clearAll() async {
    // Stop background services that may keep writing data.
    try {
      await PersistentStepCounterService.stopBackgroundService();
      await PersistentStepCounterService.dispose();
    } catch (e) {
      print('[cleanup] Step counter stop failed: $e');
    }

    // Clear SharedPreferences keys.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _prefKeys) {
        await prefs.remove(key);
      }

      // Remove dynamic route cache keys.
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('routes_popular_cache_v1_')) {
          await prefs.remove(key);
        }
        if (key.startsWith('leaderboard_cache_v2:')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('[cleanup] SharedPreferences cleanup failed: $e');
    }

    // Clear Hive boxes.
    for (final boxName in _hiveBoxes) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
          continue;
        }
        final exists = await Hive.boxExists(boxName);
        if (exists) {
          final box = await Hive.openBox(boxName);
          await box.clear();
          await box.close();
        }
      } catch (e) {
        print('[cleanup] Hive box "$boxName" cleanup failed: $e');
      }
    }

    // Clear cached network images (disk).
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      print('[cleanup] Image cache cleanup failed: $e');
    }

    // Clear in-memory image cache.
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      print('[cleanup] In-memory image cache cleanup failed: $e');
    }
  }
}
