import 'package:hive/hive.dart';

class StudentCacheService {
  static const String _boxName = 'students_cache';
  static const String _studentsKey = 'students';
  static const String _lastSyncKey = 'last_sync';

  /// Lưu danh sách students vào cache
  static Future<void> cacheStudents(List<Map<String, dynamic>> students) async {
    final box = await Hive.box(_boxName);
    await box.put(_studentsKey, students);
    await box.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Lấy danh sách students từ cache
  static List<Map<String, dynamic>>? getCachedStudents() {
    final box = Hive.box(_boxName);
    final data = box.get(_studentsKey);
    if (data == null) return null;

    return List<Map<String, dynamic>>.from(
        (data as List).map((item) => Map<String, dynamic>.from(item))
    );
  }

  /// Kiểm tra có cache không
  static bool hasCache() {
    final box = Hive.box(_boxName);
    return box.containsKey(_studentsKey);
  }

  /// Lấy thời gian sync cuối cùng
  static DateTime? getLastSyncTime() {
    final box = Hive.box(_boxName);
    final timeStr = box.get(_lastSyncKey) as String?;
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// Xóa cache
  static Future<void> clearCache() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }
}