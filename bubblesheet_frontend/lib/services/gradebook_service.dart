import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bubblesheet_frontend/services/api_service.dart';
import 'auth_helper.dart';

class GradeBookService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<GradeBookData> getGradeBook(
    String classCode,
    String token,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/classes/$classCode/gradebook/');
      print('[GradeBookService] Getting gradebook for class: $classCode');

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('[GradeBookService] Timeout getting gradebook');
              throw Exception('Request timeout');
            },
          );

      print(
        '[GradeBookService] Get gradebook response: ${response.statusCode}',
      );

      checkAuthError(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final gradebook = GradeBookData.fromJson(data);
        print(
          '[GradeBookService] Loaded gradebook: ${gradebook.students.length} students, ${gradebook.exams.length} exams',
        );
        return gradebook;
      } else {
        print(
          '[GradeBookService] Get gradebook failed: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to load gradebook: Status ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('[GradeBookService] Error getting gradebook: $e');
      print('[GradeBookService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Data model for GradeBook
class GradeBookData {
  final String classCode;
  final String className;
  final List<StudentInfo> students;
  final List<ExamInfo> exams;
  final Map<String, GradeEntry> grades; // Key: "student_id_exam_id"

  GradeBookData({
    required this.classCode,
    required this.className,
    required this.students,
    required this.exams,
    required this.grades,
  });

  factory GradeBookData.fromJson(Map<String, dynamic> json) {
    final students =
        (json['students'] as List?)
            ?.map((s) => StudentInfo.fromJson(s))
            .toList() ??
        [];
    final exams =
        (json['exams'] as List?)?.map((e) => ExamInfo.fromJson(e)).toList() ??
        [];
    final gradesMap = <String, GradeEntry>{};
    if (json['grades'] is Map) {
      (json['grades'] as Map).forEach((key, value) {
        gradesMap[key] = GradeEntry.fromJson(value);
      });
    }

    return GradeBookData(
      classCode: json['class_code'] ?? '',
      className: json['class_name'] ?? '',
      students: students,
      exams: exams,
      grades: gradesMap,
    );
  }

  /// Get grade for a specific student and exam
  GradeEntry? getGrade(String studentId, String examId) {
    return grades['${studentId}_$examId'];
  }
}

class StudentInfo {
  final String id;
  final String studentId;
  final String name;
  final String firstName;
  final String lastName;

  StudentInfo({
    required this.id,
    required this.studentId,
    required this.name,
    required this.firstName,
    required this.lastName,
  });

  factory StudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      name: json['name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
    );
  }
}

class ExamInfo {
  final String id;
  final String name;
  final String date;

  ExamInfo({required this.id, required this.name, required this.date});

  factory ExamInfo.fromJson(Map<String, dynamic> json) {
    return ExamInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      date: json['date'] ?? '',
    );
  }
}

class GradeEntry {
  final double? score;
  final double? percentage;
  final String? scannedAt;

  GradeEntry({this.score, this.percentage, this.scannedAt});

  factory GradeEntry.fromJson(Map<String, dynamic> json) {
    return GradeEntry(
      score: json['score']?.toDouble(),
      percentage: json['percentage']?.toDouble(),
      scannedAt: json['scanned_at'],
    );
  }
}
