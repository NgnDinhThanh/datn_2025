import 'package:hive/hive.dart';

class AnswerKeyCacheService {
  static const String _boxName = 'answer_keys_cache';

  static Future<void> cacheAnswerKey(
    String quizId,
    Map<String, dynamic> answerKey,
  ) async {
    final box = Hive.box(_boxName);
    await box.put('answer_key_$quizId', answerKey);
  }

  static Map<String, dynamic>? getAnswerKey(String quizId) {
    final box = Hive.box(_boxName);
    final data = box.get('answer_key_$quizId');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static bool hasAnswerKey(String quizId) {
    final box = Hive.box(_boxName);
    return box.containsKey('answer_key_$quizId');
  }

  static Future<void> clearAnswerKey(String quizId) async {
    final box = Hive.box(_boxName);
    await box.delete('answer_key_$quizId');
  }

  static Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }

  static Map<String, dynamic>? gradeOffline({
    required String quizId,
    required String versionCode,
    required Map<String, dynamic> studentAnswers,
  }) {
    final answerKey = getAnswerKey(quizId);
    if (answerKey == null) {
      print('[gradeOffline] No cached answer key for quiz: $quizId');
      return null;
    }

    print('[gradeOffline] Answer key: $answerKey');
    print('[gradeOffline] Looking for version: $versionCode');
    print('[gradeOffline] Student answers: $studentAnswers');

    // Tìm version phù hợp
    final versions = answerKey['versions'] as List?;
    if (versions == null || versions.isEmpty) {
      print('[gradeOffline] No versions found');
      return null;
    }

    Map<String, dynamic>? matchedVersion;
    for (final v in versions) {
      final vCode = v['version_code']?.toString() ?? '';
      print('[gradeOffline] Checking version: $vCode');
      if (vCode == versionCode || vCode == versionCode.padLeft(3, '0')) {
        matchedVersion = Map<String, dynamic>.from(v);
        break;
      }
    }

    // STRICT: Nếu không tìm thấy version -> trả 0 điểm + báo lỗi (không fallback)
    if (matchedVersion == null) {
      final totalQuestionsFallback = _inferTotalQuestionsFromVersions(versions);
      print('[gradeOffline] Version not found: $versionCode');
      return {
        'score': 0,
        'totalQuestions': totalQuestionsFallback,
        'percentage': 0.0,
        'correctAnswers': <String, int>{},
        'error': 'Version code $versionCode not found in answer key',
        'versionNotFound': true,
      };
    }

    final questions = matchedVersion['questions'] as List?;
    if (questions == null || questions.isEmpty) {
      print('[gradeOffline] No questions in version');
      return null;
    }

    print('[gradeOffline] Found ${questions.length} questions');

    final correctAnswers = <String, int>{};
    for (final q in questions) {
      final order = q['order'];
      final answer = q['answer'] as String?;

      if (order != null && answer != null && answer.isNotEmpty) {
        final answerIndex =
            answer.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
        correctAnswers[order.toString()] = answerIndex;
        print('[gradeOffline] Q$order: correct=$answer (index=$answerIndex)');
      }
    }

    int score = 0;
    final totalQuestions = correctAnswers.length;

    for (final entry in correctAnswers.entries) {
      final questionKey = entry.key;
      final correctIndex = entry.value;

      final studentAnswer = studentAnswers[questionKey];
      int? studentIndex;

      if (studentAnswer is int) {
        studentIndex = studentAnswer;
      } else if (studentAnswer is List && studentAnswer.isNotEmpty) {
        studentIndex = studentAnswer[0] as int?;
      } else if (studentAnswer is String) {
        studentIndex = int.tryParse(studentAnswer);
      }

      print(
        '[gradeOffline] Q$questionKey: student=$studentIndex, correct=$correctIndex, match=${studentIndex == correctIndex}',
      );

      if (studentIndex != null && studentIndex == correctIndex) {
        score++;
      }
    }

    final percentage = totalQuestions > 0
        ? (score / totalQuestions * 100).roundToDouble()
        : 0.0;

    print('[gradeOffline] Final: $score / $totalQuestions = $percentage%');

    return {
      'score': score,
      'totalQuestions': totalQuestions,
      'percentage': percentage,
      'correctAnswers': correctAnswers,
    };
  }

  static int _inferTotalQuestionsFromVersions(List versions) {
    try {
      final first = versions.isNotEmpty ? versions[0] : null;
      if (first is Map && first['questions'] is List) {
        return (first['questions'] as List).length;
      }
    } catch (_) {}
    return 0;
  }
}
