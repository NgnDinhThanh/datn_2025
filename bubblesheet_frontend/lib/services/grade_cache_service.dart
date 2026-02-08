import 'package:bubblesheet_frontend/models/grade_model.dart';
import 'package:hive/hive.dart';

class GradeCacheService {
  static const String _boxName = 'grades_cache';

  static Future<void> cacheGradesForQuiz(
    String quizId,
    List<GradeModel> grades,
  ) async {
    final box = Hive.box(_boxName);
    final key = 'grades_quiz_$quizId';

    final gradesJson = grades.map((g) => g.toJson()).toList();
    await box.put(key, gradesJson);
    await box.put('${key}_last_sync', DateTime.now().toIso8601String());
  }

  static List<GradeModel>? getCachedGradesForQuiz(String quizId) {
    final box = Hive.box(_boxName);
    final key = 'grades_quiz_$quizId';
    final data = box.get(key);

    if (data == null) return null;

    try {
      final gradesJson = List<Map<String, dynamic>>.from(
        (data as List).map((item) => Map<String, dynamic>.from(item as Map)),
      );
      return gradesJson.map((json) => GradeModel.fromJson(json)).toList();
    } catch (e) {
      print("[GradeCache] Error parsing cached grade: $e");
      return null;
    }
  }

  static int getCacheGradesCount(String quizId) {
    final grades = getCachedGradesForQuiz(quizId);
    return grades?.length ?? 0;
  }

  static Future<void> clearGradesForQuiz(String quizId) async {
    final box = Hive.box(_boxName);
    final key = 'grades_quiz_$quizId';
    await box.delete(key);
    await box.delete('${key}_last_sync');
  }

  static Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }
}
