import 'package:hive/hive.dart';

class GradingResultQueueService {
  static const String _boxName = 'grading_results_queue';

  /// Thêm kết quả vào hàng đợi
  static Future<void> addToQueue(Map<String, dynamic> result) async {
    final box = Hive.box(_boxName);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(id, {
      'id': id,
      'data': result,
      'createdAt': DateTime.now().toIso8601String(),
      'synced': false,
    });
    print('[Queue] Added result to queue: $id');
  }

  /// Lấy tất cả kết quả chưa sync
  static List<Map<String, dynamic>> getPendingResults() {
    final box = Hive.box(_boxName);
    final results = <Map<String, dynamic>>[];

    for (var key in box.keys) {
      final item = box.get(key);
      if (item != null && item['synced'] == false) {
        results.add(Map<String, dynamic>.from(item));
      }
    }

    print('[Queue] Pending results: ${results.length}');
    return results;
  }

  /// Đánh dấu đã sync thành công
  static Future<void> markAsSynced(String id) async {
    final box = Hive.box(_boxName);
    final item = box.get(id);
    if (item != null) {
      item['synced'] = true;
      await box.put(id, item);
      print('[Queue] Marked as synced: $id');
    }
  }

  /// Xóa kết quả đã sync
  static Future<void> removeFromQueue(String id) async {
    final box = Hive.box(_boxName);
    await box.delete(id);
    print('[Queue] Removed from queue: $id');
  }

  /// Xóa tất cả kết quả đã sync
  static Future<void> clearSyncedResults() async {
    final box = Hive.box(_boxName);
    final keysToRemove = <dynamic>[];

    for (var key in box.keys) {
      final item = box.get(key);
      if (item != null && item['synced'] == true) {
        keysToRemove.add(key);
      }
    }

    for (var key in keysToRemove) {
      await box.delete(key);
    }
    print('[Queue] Cleared ${keysToRemove.length} synced results');
  }

  /// Đếm số kết quả chờ sync
  static int getPendingCount() {
    final box = Hive.box(_boxName);
    int count = 0;
    for (var key in box.keys) {
      final item = box.get(key);
      if (item != null && item['synced'] == false) {
        count++;
      }
    }
    return count;
  }
}