import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bubblesheet_frontend/models/grade_model.dart';
import 'package:bubblesheet_frontend/services/api_service.dart';

class GradingService {
  static String get baseUrl => ApiService.baseUrl;

  /// Check if answer key exists for a quiz
  static Future<bool> checkAnswerKey(String quizId, String token) async {
    try {
      // Normalize quiz_id (remove ObjectId wrapper if present)
      String normalizedQuizId = quizId;
      if (quizId.startsWith('ObjectId(')) {
        normalizedQuizId = quizId.substring(9, quizId.length - 2);
      }
      
      final url = Uri.parse('$baseUrl/grading/check-answer-key/?quiz_id=$normalizedQuizId');
      print('[GradingService] Checking answer key: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[GradingService] Timeout checking answer key');
          throw Exception('Request timeout');
        },
      );

      print('[GradingService] Answer key check response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hasKey = data['has_answer_key'] ?? false;
        print('[GradingService] Has answer key: $hasKey');
        return hasKey;
      } else {
        print('[GradingService] Answer key check failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('[GradingService] Error checking answer key: $e');
      print('[GradingService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get all grades for a quiz
  static Future<List<GradeModel>> getGradesForQuiz(String quizId, String token) async {
    try {
      // Normalize quiz_id (remove ObjectId wrapper if present)
      String normalizedQuizId = quizId;
      if (quizId.startsWith('ObjectId(')) {
        normalizedQuizId = quizId.substring(9, quizId.length - 2);
      }
      
      final url = Uri.parse('$baseUrl/grading/grades/by-quiz/?quiz_id=$normalizedQuizId');
      print('[GradingService] Getting grades for quiz: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[GradingService] Timeout getting grades');
          throw Exception('Request timeout');
        },
      );

      print('[GradingService] Get grades response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        final grades = results.map((json) => GradeModel.fromJson(json)).toList();
        print('[GradingService] Loaded ${grades.length} grades');
        return grades;
      } else {
        print('[GradingService] Get grades failed: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load grades: Status ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('[GradingService] Error getting grades: $e');
      print('[GradingService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get item analysis for a quiz
  static Future<ItemAnalysisModel> getItemAnalysis(String quizId, String token) async {
    try {
      final url = Uri.parse('$baseUrl/grading/item-analysis/?quiz_id=$quizId');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ItemAnalysisModel.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to load item analysis');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all grades for a class
  static Future<List<GradeModel>> getGradesForClass(String classCode, String token) async {
    try {
      final url = Uri.parse('$baseUrl/grading/grades/?class_code=$classCode');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data is List ? data : (data['results'] as List? ?? []);
        return results.map((json) => GradeModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load grades: Status ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all grades for a student
  static Future<List<GradeModel>> getGradesForStudent(String studentId, String token) async {
    try {
      final url = Uri.parse('$baseUrl/grading/grades/?student_id=$studentId');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data is List ? data : (data['results'] as List? ?? []);
        return results.map((json) => GradeModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load grades: Status ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

