import 'package:hive/hive.dart';

class AnswerSheetTemplateCacheService {
  static const String _boxName = 'answer_sheet_templates_cache';

  /// Lưu template vào cache theo answersheetId
  static Future<void> cacheTemplate(
    String answersheetId,
    Map<String, dynamic> template,
  ) async {
    final box = Hive.box(_boxName);
    await box.put('template_$answersheetId', template);
    print('[AnswerSheetTemplateCache] Cached template for answersheet: $answersheetId');
  }

  /// Lấy template từ cache theo answersheetId
  static Map<String, dynamic>? getTemplate(String answersheetId) {
    final box = Hive.box(_boxName);
    final data = box.get('template_$answersheetId');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Kiểm tra có cache template không
  static bool hasTemplate(String answersheetId) {
    final box = Hive.box(_boxName);
    return box.containsKey('template_$answersheetId');
  }

  /// Xóa template cache
  static Future<void> clearTemplate(String answersheetId) async {
    final box = Hive.box(_boxName);
    await box.delete('template_$answersheetId');
    print('[AnswerSheetTemplateCache] Cleared template for answersheet: $answersheetId');
  }

  /// Xóa tất cả template cache
  static Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
    print('[AnswerSheetTemplateCache] Cleared all templates');
  }
}













