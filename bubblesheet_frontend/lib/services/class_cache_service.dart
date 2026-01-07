import 'package:hive/hive.dart';

class ClassCacheService {
  static const String _boxName = 'classes_cache';
  static const String _classesKey = 'classes';
  static const String _lastSyncKey = 'last_sync';

  static Future<void> cacheClasses(List<Map<String, dynamic>> classes) async {
    final box = Hive.box(_boxName);
    await box.put(_classesKey, classes);
    await box.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>>? getCachedClasses() {
    final box = Hive.box(_boxName);
    final data = box.get(_classesKey);
    if (data == null) return null;

    return List<Map<String, dynamic>>.from(
        (data as List).map((item) => Map<String, dynamic>.from(item))
    );
  }

  static bool hasCache() {
    final box = Hive.box(_boxName);
    return box.containsKey(_classesKey);
  }

  static DateTime? getLastSyncTime() {
    final box = Hive.box(_boxName);
    final timeStr = box.get(_lastSyncKey) as String?;
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  static Future<void> clearCache() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }
}