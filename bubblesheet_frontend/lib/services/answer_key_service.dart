import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/api_service.dart';
import '../models/answer_key_model.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class AnswerKeyService {
  static Future<Map<String, dynamic>> generateAnswerKeys({
    required BuildContext context,
    required String quizId,
    required int numVersions,
    required PlatformFile answerFile,
  }) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final uri = Uri.parse('${ApiService.baseUrl}/answer-keys/generate/');
    final request = http.MultipartRequest('POST', uri)
      ..fields['quiz_id'] = quizId
      ..fields['num_versions'] = numVersions.toString()
      ..headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes(
        'answer_file',
        answerFile.bytes!,
        filename: answerFile.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'data': json.decode(response.body),
      };
    } else {
      return {
        'success': false,
        'error': response.body,
      };
    }
  }

  static Future<List<AnswerKeyModel>> getAnswerKeys({
    required BuildContext context,
    required String quizId,
  }) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final uri = Uri.parse('${ApiService.baseUrl}/answer-keys/quiz/$quizId/');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data as List).map((e) => AnswerKeyModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load answer keys');
    }
  }

  static Future<void> downloadAllAnswerKeysExcel(BuildContext context, String quizId) async {
    if (!kIsWeb) {
      // Mobile không hỗ trợ download
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download functionality is only available on web')),
      );
      return;
    }
    
    try {
      // Web-only download logic
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final url = '${ApiService.baseUrl}/answer-keys/quiz/$quizId/download/';
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $token',
      });
      
      if (response.statusCode == 200) {
        // Get bytes from response
        final bytes = response.bodyBytes;
        
        // Extract filename from Content-Disposition header or generate from quizId
        String filename = 'answer_keys_$quizId.xlsx';
        final contentDisposition = response.headers['content-disposition'];
        if (contentDisposition != null) {
          // Try to extract filename from header: "attachment; filename=answer_keys_{quiz_id}.xlsx"
          // Handle both quoted and unquoted filenames
          // Pattern 1: filename="value" or filename='value' or filename=value
          final pattern1 = RegExp(r'filename\*?=([^;]+)', caseSensitive: false);
          final match1 = pattern1.firstMatch(contentDisposition);
          if (match1 != null && match1.group(1) != null) {
            String extracted = match1.group(1)!.trim();
            // Remove quotes if present
            if ((extracted.startsWith('"') && extracted.endsWith('"')) ||
                (extracted.startsWith("'") && extracted.endsWith("'"))) {
              extracted = extracted.substring(1, extracted.length - 1);
            }
            if (extracted.isNotEmpty) {
              filename = extracted;
            }
          }
        }
        
        // Create blob from response bytes
        final blob = html.Blob([bytes]);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        
        // Create anchor element and trigger download
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', filename)
          ..click();
        
        // Clean up
        html.Url.revokeObjectUrl(blobUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download started: $filename')),
        );
      } else {
        String errorMsg = 'Download failed: ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['error'] != null) {
            errorMsg = body['error'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download error: $e')),
      );
    }
  }
} 