import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
