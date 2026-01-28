import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/offline_sync_service.dart';
import '../../data/datasources/pending_sync_data_source.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final PendingSyncDataSource _pendingSyncDataSource =
      di.getIt<PendingSyncDataSource>();
  final OfflineSyncService _offlineSyncService =
      di.getIt<OfflineSyncService>();

  bool _loading = false;
  List<PendingSyncItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final items = await _pendingSyncDataSource.getPending();
      if (!mounted) return;
      setState(() => _items = items);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    try {
      await _offlineSyncService.syncPending();
    } finally {
      await _loadPending();
    }
  }

  Future<void> _clearQueue() async {
    setState(() => _loading = true);
    try {
      await _pendingSyncDataSource.clear();
    } finally {
      await _loadPending();
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Queue'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPending,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pending: ${_items.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _syncNow,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Sync now'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _clearQueue,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No pending sync items'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final payload = item.payload;
                          final size = payload['routePoints']?.length ??
                              payload['hexIds']?.length ??
                              payload['coordinates']?.length ??
                              0;
                          return ListTile(
                            leading: Icon(
                              item.type == 'activity'
                                  ? Icons.directions_run
                                  : Icons.hexagon,
                              color: item.type == 'activity'
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                            title: Text(
                              item.type == 'activity'
                                  ? 'Activity payload'
                                  : 'Territory payload',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Items: $size • ${_formatTimestamp(item.createdAt)}',
                            ),
                            trailing: Text(
                              item.id.split('-').first,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
