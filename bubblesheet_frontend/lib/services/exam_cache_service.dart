import 'package:hive/hive.dart';

class ExamCacheService {
  static const String _boxName = 'exams_cache';
  static const String _examsKey = 'exams';
  static const String _lastSyncKey = 'last_sync';

  static Future<void> cacheExams(List<Map<String, dynamic>>exams) async {
    final box = await Hive.box(_boxName);
    await box.put(_examsKey, exams);
    await box.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>>? getCachedExams() {
    final box = Hive.box(_boxName);
    final data = box.get(_examsKey);
    if (data == null) return null;

    return List<Map<String, dynamic>>.from(
        (data as List).map((item) => Map<String, dynamic>.from(item))
    );
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