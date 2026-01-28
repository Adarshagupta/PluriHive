import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';

class PendingSyncItem {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  PendingSyncItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingSyncItem.fromJson(Map<String, dynamic> json) {
    return PendingSyncItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract class PendingSyncDataSource {
  Future<void> addActivityPayload(Map<String, dynamic> payload);
  Future<void> addTerritoryPayload(Map<String, dynamic> payload);
  Future<List<PendingSyncItem>> getPending();
  Future<void> remove(String id);
  Future<void> clear();
}

class PendingSyncDataSourceImpl implements PendingSyncDataSource {
  static const String _boxName = 'pending_sync';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  @override
  Future<void> addActivityPayload(Map<String, dynamic> payload) async {
    await _addItem('activity', payload);
  }

  @override
  Future<void> addTerritoryPayload(Map<String, dynamic> payload) async {
    await _addItem('territory', payload);
  }

  Future<void> _addItem(String type, Map<String, dynamic> payload) async {
    final box = await _getBox();
    final item = PendingSyncItem(
      id: _generateId(),
      type: type,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );
    await box.put(item.id, item.toJson());
    print('[sync] Pending queued: ${item.type} (${item.id})');
  }

  @override
  Future<List<PendingSyncItem>> getPending() async {
    final box = await _getBox();
    final items = <PendingSyncItem>[];
    for (final key in box.keys) {
      try {
        final json = Map<String, dynamic>.from(box.get(key) as Map);
        items.add(PendingSyncItem.fromJson(json));
      } catch (e) {
        print('[warn] Pending load error for $key: $e');
      }
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<void> remove(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  @override
  Future<void> clear() async {
    final box = await _getBox();
    await box.clear();
  }

  String _generateId() {
    final random = Random();
    final salt = random.nextInt(1 << 32);
    return '${DateTime.now().microsecondsSinceEpoch}-$salt';
  }
}
