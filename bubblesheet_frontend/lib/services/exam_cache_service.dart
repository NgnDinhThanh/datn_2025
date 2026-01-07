import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExamCacheService {
  static const String _boxName = 'exams_cache';
  static const String _examsKey = 'exams';
  static const String _lastSyncKey = 'last_sync';

  static Future<void> cacheExams(List<Map<String, dynamic>>exams) async {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return;
    
    try {
      final box = await Hive.box(_boxName);
      await box.put(_examsKey, exams);
      await box.put(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('[ExamCache] Error caching exams: $e');
    }
  }

  static List<Map<String, dynamic>>? getCachedExams() {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return null;
    
    try {
      final box = Hive.box(_boxName);
      final data = box.get(_examsKey);
      if (data == null) return null;

      return List<Map<String, dynamic>>.from(
          (data as List).map((item) => Map<String, dynamic>.from(item))
      );
    } catch (e) {
      print('[ExamCache] Error getting cached exams: $e');
      return null;
    }
  }

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

  static Future<void> clearCache() async {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return;
    
    try {
      final box = Hive.box(_boxName);
      await box.clear();
    } catch (e) {
      print('[ExamCache] Error clearing cache: $e');
    }
  }
}