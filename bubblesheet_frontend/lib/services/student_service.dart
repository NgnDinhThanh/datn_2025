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

  static Future<Map<String, dynamic>> addStudent(Map<String, dynamic> data, String? token) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/students/'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
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

  static Future<Map<String, dynamic>> importStudents(String filePath, bool hasHeader, String? token) async {
    var request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/students/import/'));
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

  static Future<Student> fetchStudentById(String studentId, String? token) async {
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

  static Future<void> updateStudent(String studentId, Map<String, dynamic> data, String? token) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/students/$studentId/'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode != 200) {
      throw Exception('Failed to update student: Status ${response.statusCode}');
    }
  }

  static Future<void> deleteStudent(String studentId, String? token) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/students/$studentId/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete student: Status ${response.statusCode}');
    }
  }
} 