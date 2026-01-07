import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/answer_sheet_model.dart';
import 'api_service.dart';
import 'auth_helper.dart';

class AnswerSheetService {
  static Future<List<AnswerSheet>> getAnswerSheets(String? token) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/answer-sheets/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    
    checkAuthError(response.statusCode, response.body);
    
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List<dynamic> data = body is Map && body.containsKey('results')
          ? body['results']
          : (body is List ? body : []);
      return data.map((e) => AnswerSheet.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load answer sheets');
    }
  }

  static Future<void> createAnswerSheet(Map<String, dynamic> data, String? token) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/answer-sheets/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      String errorMsg = 'Failed to create answer sheet';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          errorMsg = body['error'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<Uint8List> generatePreview(Map<String, dynamic> data, String? token) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/answer-sheets/generate_preview/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String errorMsg = 'Failed to generate preview';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          errorMsg = body['error'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<Uint8List> downloadAnswerSheetPdf(String id, String? token) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/answer-sheets/$id/download/pdf/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String errorMsg = 'Failed to download PDF';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          errorMsg = body['error'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<Uint8List> downloadAnswerSheetPng(String id, String? token) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/answer-sheets/$id/download/png/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String errorMsg = 'Failed to download PNG';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          errorMsg = body['error'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<void> deleteAnswerSheet(String id, String? token) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/answer-sheets/$id/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 204) {
      String errorMsg = 'Failed to delete answer sheet';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          errorMsg = body['error'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  // Thêm các hàm create, delete, ... nếu cần
} 