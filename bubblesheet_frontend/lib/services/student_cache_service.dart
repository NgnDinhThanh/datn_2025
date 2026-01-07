import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StudentCacheService {
  static const String _boxName = 'students_cache';
  static const String _studentsKey = 'students';
  static const String _lastSyncKey = 'last_sync';

  /// Lưu danh sách students vào cache
  static Future<void> cacheStudents(List<Map<String, dynamic>> students) async {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return;
    
    try {
      final box = await Hive.box(_boxName);
      await box.put(_studentsKey, students);
      await box.put(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('[StudentCache] Error caching students: $e');
    }
  }

  /// Lấy danh sách students từ cache
  static List<Map<String, dynamic>>? getCachedStudents() {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return null;
    
    try {
      final box = Hive.box(_boxName);
      final data = box.get(_studentsKey);
      if (data == null) return null;

      return List<Map<String, dynamic>>.from(
          (data as List).map((item) => Map<String, dynamic>.from(item))
      );
    } catch (e) {
      print('[StudentCache] Error getting cached students: $e');
      return null;
    }
  }

  /// Kiểm tra có cache không
  static bool hasCache() {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return false;
    
    try {
      final box = Hive.box(_boxName);
      return box.containsKey(_studentsKey);
    } catch (e) {
      return false;
    }
  }

  /// Lấy thời gian sync cuối cùng
  static DateTime? getLastSyncTime() {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return null;
    
    try {
      final box = Hive.box(_boxName);
      final timeStr = box.get(_lastSyncKey) as String?;
      if (timeStr == null) return null;
      return DateTime.tryParse(timeStr);
    } catch (e) {
      return null;
    }
  }

  /// Xóa cache
  static Future<void> clearCache() async {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return;
    
    try {
      final box = Hive.box(_boxName);
      await box.clear();
    } catch (e) {
      print('[StudentCache] Error clearing cache: $e');
    }
  }
}