import 'package:hive/hive.dart';
import '../models/grade_model.dart';

class ItemAnalysisCacheService {
  static const String _boxName = 'item_analysis_cache';

  static Future<void> cacheItemAnalysis(
    String quizId,
    ItemAnalysisModel analysis,
  ) async {
    final box = Hive.box(_boxName);
    final key = 'analysis_quiz_$quizId';

    final analysisJson = {
      'quiz_id': analysis.quizId,
      'total_papers': analysis.totalPapers,
      'num_questions': analysis.numQuestions,
      'items': analysis.items
          .map(
            (item) => {
              'question_number': item.questionNumber,
              'correct_answer': item.correctAnswer,
              'correct_count': item.correctCount,
              'incorrect_count': item.incorrectCount,
              'blank_count': item.blankCount,
              'correct_percent': item.correctPercent,
              'incorrect_percent': item.incorrectPercent,
              'blank_percent': item.blankPercent,
            },
          )
          .toList(),
      'statistics': {
        'min_score': analysis.statistics.minScore,
        'max_score': analysis.statistics.maxScore,
        'average_score': analysis.statistics.averageScore,
        'average_percent': analysis.statistics.averagePercent,
        'median_score': analysis.statistics.medianScore,
        'std_deviation': analysis.statistics.stdDeviation,
      },
    };

    await box.put(key, analysisJson);
    await box.put('${key}_last_sync', DateTime.now().toIso8601String());
  }

  static ItemAnalysisModel? getCachedItemAnalysis(String quizId) {
    final box = Hive.box(_boxName);
    final key = 'analysis_quiz_$quizId';
    final data = box.get(key);

    if (data == null) return null;

    try {
      if (data is! Map) {
        print(
          '[ItemAnalysisCache] Error: data is not a Map, type: ${data.runtimeType}',
        );
        return null;
      }

      final json = Map<String, dynamic>.from(data as Map);

      if (json['items'] is List) {
        json['items'] = (json['items'] as List).map((item) {
          if (item is Map) return Map<String, dynamic>.from(item as Map);
          return item;
        }).toList();
      }

      if (json['statistics'] is Map) {
        json['statistics'] = Map<String, dynamic>.from(
          json['statistics'] as Map,
        );
      }

      return ItemAnalysisModel.fromJson(json);
    } catch (e, st) {
      print('[ItemAnalysisCache] Error parsing cached analysis: $e');
      print(st);
      return null;
    }
  }

  static Future<void> clearAnalysisForQuiz(String quizId) async {
    final box = Hive.box(_boxName);
    final key = 'analysis_quiz_$quizId';
    await box.delete(key);
    await box.delete('${key}_last_sync');
  }

  static Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }
}
