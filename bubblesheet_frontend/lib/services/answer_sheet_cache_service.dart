import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/answer_sheet_model.dart';

class AnswerSheetCacheService {
  static const String _boxName = 'answer_sheets_cache';

  static Future<void> cacheAnswerSheets(
    List<Map<String, dynamic>> sheetsJson,
  ) async {
    if (kIsWeb) return;

    try {
      final box = Hive.box(_boxName);
      await box.put('answer_sheets', sheetsJson);
    } catch (e) {
      print('[AnswerSheetCache] Error caching answer sheets: $e');
    }
  }

  static List<Map<String, dynamic>>? getCachedAnswerSheets() {
    if (kIsWeb) return null;

    try {
      final box = Hive.box(_boxName);
      final data = box.get('answer_sheets');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      print('[AnswerSheetCache] Error getting cached answer sheets: $e');
      return null;
    }
  }

  static Future<void> clearAll() async {
    if (kIsWeb) return;

    try {
      final box = Hive.box(_boxName);
      await box.clear();
    } catch (e) {
      print('[AnswerSheetCache] Error clearing cache: $e');
    }
  }
}
