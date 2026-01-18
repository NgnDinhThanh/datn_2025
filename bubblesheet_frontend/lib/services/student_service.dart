import 'dart:convert';
import 'package:bubblesheet_frontend/models/student_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_service.dart';
import 'auth_helper.dart';

class StudentService {
  static Future<List<Student>> getStudents(String? token) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/students/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Student.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load students: Status ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> addStudent(
    Map<String, dynamic> data,
    String? token,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/students/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    checkAuthError(response.statusCode, response.body);
    return _processResponse(response);
  }

  static Map<String, dynamic> _processResponse(http.Response response) {
    final Map<String, dynamic> result = {};
    result['statusCode'] = response.statusCode;
    try {
      result['body'] = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      result['body'] = response.body;
    }
    return result;
  }

  static Future<Map<String, dynamic>> importStudents(
    String filePath,
    bool hasHeader,
    String? token,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/students/import/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['has_header'] = hasHeader ? 'true' : 'false';
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    checkAuthError(response.statusCode, response.body);
    final Map<String, dynamic> result = {};
    result['statusCode'] = response.statusCode;
    try {
      result['body'] = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      result['body'] = response.body;
    }
    return result;
  }

  static Future<Student> fetchStudentById(
    String studentId,
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/students/$studentId/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Student.fromJson(data);
    } else {
      throw Exception('Failed to fetch student: Status ${response.statusCode}');
    }
  }

  static Future<void> updateStudent(
    String studentId,
    Map<String, dynamic> data,
    String? token,
  ) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/students/$studentId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update student: Status ${response.statusCode}',
      );
    }
  }

  static Future<void> deleteStudent(String studentId, String? token) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/students/$studentId/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode != 204) {
      throw Exception(
        'Failed to delete student: Status ${response.statusCode}',
      );
    }
  }

  /// Get detailed student information including graded papers
  static Future<StudentDetailData> getStudentDetail(String studentId, String token) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/students/$studentId/detail/');
      print('[StudentService] Getting student detail: $studentId');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[StudentService] Timeout getting student detail');
          throw Exception('Request timeout');
        },
      );

      print('[StudentService] Get student detail response: ${response.statusCode}');

      checkAuthError(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final studentDetail = StudentDetailData.fromJson(data);
        print('[StudentService] Loaded student detail: ${studentDetail.gradedPapers.length} graded papers');
        return studentDetail;
      } else {
        print('[StudentService] Get student detail failed: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load student detail: Status ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('[StudentService] Error getting student detail: $e');
      print('[StudentService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Data model for Student Detail with Graded Papers
class StudentDetailData {
  final String studentId;
  final String firstName;
  final String lastName;
  final String fullName;
  final List<ClassInfo> classes;
  final List<GradedPaper> gradedPapers;

  StudentDetailData({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.classes,
    required this.gradedPapers,
  });

  factory StudentDetailData.fromJson(Map<String, dynamic> json) {
    final classes = (json['classes'] as List?)
            ?.map((c) => ClassInfo.fromJson(c))
            .toList() ??
        [];
    final gradedPapers = (json['graded_papers'] as List?)
            ?.map((p) => GradedPaper.fromJson(p))
            .toList() ??
        [];

    return StudentDetailData(
      studentId: json['student_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '',
      classes: classes,
      gradedPapers: gradedPapers,
    );
  }
}

class ClassInfo {
  final String id;
  final String classCode;
  final String className;

  ClassInfo({
    required this.id,
    required this.classCode,
    required this.className,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassInfo(
      id: json['id'] ?? '',
      classCode: json['class_code'] ?? '',
      className: json['class_name'] ?? '',
    );
  }
}

class GradedPaper {
  final String gradeId;
  final String classCode;
  final String? className;
  final String examId;
  final String? examName;
  final String? examDate;
  final double? score;
  final double? percentage;
  final String? versionCode; // "Key" field
  final String? scannedAt; // Timestamp

  GradedPaper({
    required this.gradeId,
    required this.classCode,
    this.className,
    required this.examId,
    this.examName,
    this.examDate,
    this.score,
    this.percentage,
    this.versionCode,
    this.scannedAt,
  });

  factory GradedPaper.fromJson(Map<String, dynamic> json) {
    return GradedPaper(
      gradeId: json['grade_id'] ?? '',
      classCode: json['class_code'] ?? '',
      className: json['class_name'],
      examId: json['exam_id'] ?? '',
      examName: json['exam_name'],
      examDate: json['exam_date'],
      score: json['score']?.toDouble(),
      percentage: json['percentage']?.toDouble(),
      versionCode: json['version_code'],
      scannedAt: json['scanned_at'],
    );
  }
}
