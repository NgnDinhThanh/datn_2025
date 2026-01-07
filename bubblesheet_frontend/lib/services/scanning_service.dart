import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:bubblesheet_frontend/models/scanning_result.dart';
import 'package:bubblesheet_frontend/services/api_service.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ScanningService {
  // Luôn lấy baseUrl mới nhất từ ApiService (có thể thay đổi khi switch IP)
  static String get baseUrl => ApiService.baseUrl;

  /// Preview check - Check if ArUco markers are detected
  static Future<PreviewCheckResult> previewCheck(File imageFile, String token) async {
    try {
      final url = Uri.parse('$baseUrl/grading/preview-check/');
      
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PreviewCheckResult.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Preview check failed');
      }
    } catch (e) {
      throw Exception('Preview check error: $e');
    }
  }

  // Get answer key for a quiz (cache and offline grade)
  static Future<Map<String, dynamic>?> getAnswerKey({required String quizId, required String token}) async {
    try {
      final uri = Uri.parse('$baseUrl/answer-keys/quiz/$quizId/');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return Map<String, dynamic>.from(data[0]);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Get answer key error: $e');
    }
  }

  /// Scan and grade answer sheet
  static Future<ScanningResult> scanAndGrade({
    required File imageFile,
    required String quizId,
    required String answersheetId,
    required String token,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/grading/scan/');
      
      // Tối ưu: Resize ảnh trước khi gửi để giảm upload time
      // Full resolution có thể rất lớn (5-10MB), resize xuống 2000x3000 vẫn đủ để chấm
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      File? optimizedFile;
      if (originalImage != null) {
        // Resize nếu ảnh quá lớn (giữ tỷ lệ)
        img.Image? resizedImage;
        if (originalImage.width > 2000 || originalImage.height > 3000) {
          // Tính toán kích thước mới giữ tỷ lệ
          double scale = 2000 / originalImage.width;
          if (3000 / originalImage.height < scale) {
            scale = 3000 / originalImage.height;
          }
          final newWidth = (originalImage.width * scale).round();
          final newHeight = (originalImage.height * scale).round();
          
          resizedImage = img.copyResize(
            originalImage,
            width: newWidth,
            height: newHeight,
            interpolation: img.Interpolation.linear,
          );
        } else {
          resizedImage = originalImage;
        }
        
        // Compress với quality 90% (đủ để chấm chính xác)
        final compressedBytes = img.encodeJpg(resizedImage, quality: 90);
        
        // Tạo file tạm cho ảnh đã optimize
        final tempDir = Directory.systemTemp;
        optimizedFile = File(path.join(tempDir.path, 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg'));
        await optimizedFile.writeAsBytes(compressedBytes);
      }
      
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['quiz_id'] = quizId;
      request.fields['answersheet_id'] = answersheetId;
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', 
          optimizedFile?.path ?? imageFile.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Xóa file tạm sau khi gửi
      if (optimizedFile != null) {
        try {
          await optimizedFile.delete();
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScanningResult.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Scan and grade failed');
      }
    } catch (e) {
      throw Exception('Scan and grade error: $e');
    }
  }

  /// Save grade to database
  static Future<Map<String, dynamic>> saveGrade({
    required String quizId,
    required String studentId,
    required int score,
    required double percentage,
    required Map<String, dynamic> answers,
    required String versionCode,
    required String answersheetId,
    required String token,
    String? classId,
    File? scannedImage,
    File? annotatedImage,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/grading/save-grade/');
      
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['quiz_id'] = quizId;
      request.fields['student_id'] = studentId;
      request.fields['score'] = score.toString();
      request.fields['percentage'] = percentage.toString();
      request.fields['answers'] = jsonEncode(answers);
      request.fields['version_code'] = versionCode;
      request.fields['answersheet_id'] = answersheetId;
      
      if (classId != null) {
        request.fields['class_id'] = classId;
      }
      
      if (scannedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('scanned_image', scannedImage.path),
        );
      }
      
      if (annotatedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('annotated_image', annotatedImage.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Save grade failed');
      }
    } catch (e) {
      throw Exception('Save grade error: $e');
    }
  }

  /// Get template JSON for an answer sheet (dùng cho client-side scanning)
  static Future<Map<String, dynamic>> getTemplateJson({
    required String answersheetId,
    required String token,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/grading/template-json/?answersheet_id=$answersheetId',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final template = data['template'];
          if (template is Map<String, dynamic>) {
            return template;
          }
        }
        throw Exception(data['error'] ?? 'Failed to load template JSON');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to load template JSON');
      }
    } catch (e) {
      throw Exception('Get template JSON error: $e');
    }
  }
  
  /// Grade from JSON data (client-side scanned result)
  /// Gửi answers đã scan từ client lên server để chấm điểm
  static Future<ScanningResult> gradeFromJson({
    required String quizId,
    required String answersheetId,
    required String studentId,
    required String versionCode,
    required String? classId,
    required Map<String, dynamic> answers,
    required int totalQuestions,
    required String token,
    String? warpedImageBase64,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/grading/grade-from-json/');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'quiz_id': quizId,
          'answersheet_id': answersheetId,
          'student_id': studentId,
          'version_code': versionCode,
          'class_id': classId,
          'answers': answers,
          'total_questions': totalQuestions,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScanningResult.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Grade from JSON failed');
      }
    } catch (e) {
      throw Exception('Grade from JSON error: $e');
    }
  }
}




