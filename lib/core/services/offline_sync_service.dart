import 'auth_api_service.dart';
import 'tracking_api_service.dart';
import 'territory_api_service.dart';
import '../../features/tracking/data/datasources/pending_sync_data_source.dart';
import '../../features/tracking/data/datasources/activity_local_data_source.dart';

class OfflineSyncService {
  final TrackingApiService trackingApiService;
  final TerritoryApiService territoryApiService;
  final PendingSyncDataSource pendingSyncDataSource;
  final AuthApiService authApiService;
  final ActivityLocalDataSource? activityLocalDataSource;

  OfflineSyncService({
    required this.trackingApiService,
    required this.territoryApiService,
    required this.pendingSyncDataSource,
    required this.authApiService,
    this.activityLocalDataSource,
  });

  Future<void> queueActivityPayload(Map<String, dynamic> payload) async {
    await pendingSyncDataSource.addActivityPayload(payload);
  }

  Future<void> queueTerritoryPayload(Map<String, dynamic> payload) async {
    await pendingSyncDataSource.addTerritoryPayload(payload);
  }

  Future<int> syncPending() async {
    final isAuthed = await authApiService.isAuthenticated();
    if (!isAuthed) {
      print('[sync] Offline sync skipped: not authenticated');
      return 0;
    }

    final pending = await pendingSyncDataSource.getPending();
    if (pending.isEmpty) {
      return 0;
    }

    var synced = 0;
    for (final item in pending) {
      try {
        if (item.type == 'activity') {
          await trackingApiService.saveActivityPayload(item.payload);
          final clientId = item.payload['clientId']?.toString();
          if (clientId != null && clientId.isNotEmpty) {
            await activityLocalDataSource?.deleteByClientId(clientId);
          }
        } else if (item.type == 'territory') {
          await territoryApiService.captureTerritoriesPayload(item.payload);
        } else {
          print('[warn] Unknown pending sync type: ${item.type}');
        }
        await pendingSyncDataSource.remove(item.id);
        synced += 1;
      } catch (e) {
        // Keep the item for retry later
        print('[warn] Offline sync failed for ${item.id}: $e');
      }
    }

    return synced;
  }
}
