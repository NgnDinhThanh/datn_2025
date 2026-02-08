import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StudentCacheService {
  static const String _boxName = 'students_cache';
  static const String _studentsKey = 'students';
  static const String _lastSyncKey = 'last_sync';

  static Future<void> cacheStudents(List<Map<String, dynamic>> students) async {
    if (kIsWeb) return;

    try {
      final box = await Hive.box(_boxName);
      await box.put(_studentsKey, students);
      await box.put(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('[StudentCache] Error caching students: $e');
    }
  }

  static List<Map<String, dynamic>>? getCachedStudents() {
    if (kIsWeb) return null;

    try {
      final box = Hive.box(_boxName);
      final data = box.get(_studentsKey);
      if (data == null) return null;

      return List<Map<String, dynamic>>.from(
        (data as List).map((item) => Map<String, dynamic>.from(item)),
      );
    } catch (e) {
      print('[StudentCache] Error getting cached students: $e');
      return null;
    }
  }

  static bool hasCache() {
    if (kIsWeb) return false;

    try {
      final box = Hive.box(_boxName);
      return box.containsKey(_studentsKey);
    } catch (e) {
      return false;
    }
  }

  static DateTime? getLastSyncTime() {
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

  static Future<void> clearCache() async {
    if (kIsWeb) return;

    try {
      final box = Hive.box(_boxName);
      await box.clear();
    } catch (e) {
      print('[StudentCache] Error clearing cache: $e');
    }
  }
}
