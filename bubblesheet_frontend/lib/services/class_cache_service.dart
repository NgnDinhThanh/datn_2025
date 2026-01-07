import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ClassCacheService {
  static const String _boxName = 'classes_cache';
  static const String _classesKey = 'classes';
  static const String _lastSyncKey = 'last_sync';

  static Future<void> cacheClasses(List<Map<String, dynamic>> classes) async {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return;
    
    try {
      final box = Hive.box(_boxName);
      await box.put(_classesKey, classes);
      await box.put(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('[ClassCache] Error caching classes: $e');
    }
  }

  static List<Map<String, dynamic>>? getCachedClasses() {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return null;
    
    try {
      final box = Hive.box(_boxName);
      final data = box.get(_classesKey);
      if (data == null) return null;

      return List<Map<String, dynamic>>.from(
          (data as List).map((item) => Map<String, dynamic>.from(item))
      );
    } catch (e) {
      print('[ClassCache] Error getting cached classes: $e');
      return null;
    }
  }

  static bool hasCache() {
    // ✅ Bỏ qua cache trên web
    if (kIsWeb) return false;
    
    try {
      final box = Hive.box(_boxName);
      return box.containsKey(_classesKey);
    } catch (e) {
      return false;
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
      print('[ClassCache] Error clearing cache: $e');
    }
  }
}