import 'dart:convert';
import 'package:bubblesheet_frontend/models/class_model.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_helper.dart';

class ClassService {
  static Future<List<ClassModel>> getClasses(String? token) async {
    final url = '${ApiService.baseUrl}/classes/';
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      checkAuthError(response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ClassModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load classes: Status ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection') || e.toString().contains('timed out')) {
        throw Exception('Connection error: Could not connect to backend');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createClass(Map<String, dynamic> classData, String? token) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/classes/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(classData),
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create class: Status ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> updateClass(String classId, Map<String, dynamic> classData, String? token) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/classes/$classId/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(classData),
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update class: Status ${response.statusCode}');
  }

  static Future<void> deleteClass(String classId, String? token) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/classes/$classId/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete class: Status ${response.statusCode}');
    }
  }

  static Future<ClassModel> getClassDetail(String classId, String? token) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/classes/$classId/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ClassModel.fromJson(data);
    }
    throw Exception('Failed to fetch class detail: Status ${response.statusCode}');
  }
} 