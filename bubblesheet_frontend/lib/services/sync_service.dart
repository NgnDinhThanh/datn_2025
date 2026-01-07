import 'package:bubblesheet_frontend/services/api_service.dart';
import 'package:bubblesheet_frontend/services/grading_result_queue_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SyncService {
  static bool _isSyncing = false;

  /// Kiểm tra kết nối mạng
  static Future<bool> hasNetworkConnection() async {
    try {
      // Dùng endpoint không cần auth để check network
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/users/test/'))
          .timeout(const Duration(seconds: 1));
      return response.statusCode == 200; // Chỉ 200 mới OK
    } catch (e) {
      return false;
    }
  }

  /// Sync tất cả kết quả chờ lên server
  static Future<SyncResult> syncPendingResults(String token) async {
    if (_isSyncing) {
      print('[Sync] Already syncing, skip...');
      return SyncResult(synced: 0, failed: 0, pending: 0);
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    try {
      final pendingResults = GradingResultQueueService.getPendingResults();
      print('[Sync] Starting sync: ${pendingResults.length} pending results');

      for (var item in pendingResults) {
        final id = item['id'] as String;
        final data = Map<String, dynamic>.from(item['data']);

        try {
          final success = await _uploadResult(data, token);
          if (success) {
            await GradingResultQueueService.markAsSynced(id);
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          print('[Sync] Error uploading $id: $e');
          failed++;
        }
      }

      // Xóa các kết quả đã sync thành công
      await GradingResultQueueService.clearSyncedResults();

    } finally {
      _isSyncing = false;
    }

    final pending = GradingResultQueueService.getPendingCount();
    print('[Sync] Complete: synced=$synced, failed=$failed, pending=$pending');

    return SyncResult(synced: synced, failed: failed, pending: pending);
  }

  /// Upload một kết quả lên server
  static Future<bool> _uploadResult(Map<String, dynamic> data, String token) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/grading/save-grade/');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'quiz_id': data['quizId'],
          'class_id': data['classId'],
          'student_id': data['studentId'],
          'version_code': data['versionCode'],
          'answersheet_id': data['answersheetId'],
          'score': data['score'],
          'percentage': data['percentage'],
          'answers': data['answers'],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[Sync] Uploaded successfully: ${data['studentId']}');
        return true;
      } else {
        print('[Sync] Upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('[Sync] Upload error: $e');
      return false;
    }
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final int pending;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.pending,
  });
}