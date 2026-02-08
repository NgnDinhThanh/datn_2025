import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CrudOperationsQueueService {
  static const String _boxName = 'crud_operations_queue';

  static Future<void> addOperation({
    required String type, // 'CREATE' | 'UPDATE' | 'DELETE'
    required String entity, // 'Class' | 'Exam' | 'Student' | 'AnswerSheet'
    String? entityId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;

    try {
      final box = Hive.box(_boxName);
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await box.put(id, {
        'id': id,
        'type': type,
        'entity': entity,
        'entityId': entityId,
        'data': data,
        'createdAt': DateTime.now().toIso8601String(),
        'synced': false,
      });
    } catch (e) {
      print('[CrudOperationsQueue] Error adding operation: $e');
    }
  }

  static List<Map<String, dynamic>> getPendingOperations() {
    if (kIsWeb) return [];

    try {
      final box = Hive.box(_boxName);
      final ops = <Map<String, dynamic>>[];
      for (final key in box.keys) {
        final item = box.get(key);
        if (item != null && item['synced'] == false) {
          ops.add(Map<String, dynamic>.from(item as Map));
        }
      }
      ops.sort(
        (a, b) => DateTime.parse(
          a['createdAt'],
        ).compareTo(DateTime.parse(b['createdAt'])),
      );
      return ops;
    } catch (e) {
      print('[CrudOperationsQueue] Error getting pending operations: $e');
      return [];
    }
  }

  static Future<void> markAsSynced(String id) async {
    if (kIsWeb) return;

    try {
      final box = Hive.box(_boxName);
      final item = box.get(id);
      if (item != null) {
        item['synced'] = true;
        await box.put(id, item);
      }
    } catch (e) {
      print('[CrudOperationsQueue] Error marking as synced: $e');
    }
  }

  static Future<void> clearSyncedOperations() async {
    if (kIsWeb) return;

    try {
      final box = Hive.box(_boxName);
      final toRemove = <dynamic>[];
      for (final key in box.keys) {
        final item = box.get(key);
        if (item != null && item['synced'] == true) {
          toRemove.add(key);
        }
      }
      for (final key in toRemove) {
        await box.delete(key);
      }
    } catch (e) {
      print('[CrudOperationsQueue] Error clearing synced operations: $e');
    }
  }

  static int getPendingCount() {
    if (kIsWeb) return 0;

    try {
      final box = Hive.box(_boxName);
      var count = 0;
      for (final key in box.keys) {
        final item = box.get(key);
        if (item != null && item['synced'] == false) {
          count++;
        }
      }
      return count;
    } catch (e) {
      print('[CrudOperationsQueue] Error getting pending count: $e');
      return 0;
    }
  }
}
