import 'package:bubblesheet_frontend/services/api_service.dart';
import 'package:bubblesheet_frontend/services/crud_operations_queue_service.dart';
import 'package:bubblesheet_frontend/services/exam_service.dart';
import 'package:bubblesheet_frontend/services/class_service.dart';
import 'package:bubblesheet_frontend/services/student_service.dart';
import 'package:bubblesheet_frontend/services/answer_sheet_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CrudSyncResult {
  final int synced;
  final int failed;
  final int pending;

  CrudSyncResult({
    required this.synced,
    required this.failed,
    required this.pending,
  });
}

class CrudSyncService {
  static Future<CrudSyncResult> syncPendingCrudOperations(String token) async {
    int synced = 0;
    int failed = 0;

    try {
      final pendingOps = CrudOperationsQueueService.getPendingOperations();
      print(
        '[CrudSync] Starting sync: ${pendingOps.length} pending operations',
      );

      for (var op in pendingOps) {
        final id = op['id'] as String;
        final type = op['type'] as String; // 'CREATE' | 'UPDATE' | 'DELETE'
        final entity =
            op['entity']
                as String; // 'Class' | 'Exam' | 'Student' | 'AnswerSheet'
        final entityId = op['entityId'] as String?;
        final data = Map<String, dynamic>.from(op['data'] as Map);

        try {
          bool success = false;

          switch (entity) {
            case 'Exam':
              success = await _syncExamOperation(type, entityId, data, token);
              break;
            case 'Class':
              success = await _syncClassOperation(type, entityId, data, token);
              break;
            case 'Student':
              success = await _syncStudentOperation(
                type,
                entityId,
                data,
                token,
              );
              break;
            case 'AnswerSheet':
              success = await _syncAnswerSheetOperation(
                type,
                entityId,
                data,
                token,
              );
              break;
          }

          if (success) {
            await CrudOperationsQueueService.markAsSynced(id);
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          print('[CrudSync] Error syncing operation $id: $e');
          failed++;
        }
      }
      await CrudOperationsQueueService.clearSyncedOperations();
    } catch (e) {
      print('[CrudSync] Error in sync process: $e');
    }

    final pending = CrudOperationsQueueService.getPendingCount();
    print(
      '[CrudSync] Complete: synced=$synced, failed=$failed, pending=$pending',
    );

    return CrudSyncResult(synced: synced, failed: failed, pending: pending);
  }

  static Future<bool> _syncExamOperation(
    String type,
    String? examId,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      if (type == 'CREATE') {
        await ExamService.createExam(data, token);
        return true;
      } else if (type == 'UPDATE' && examId != null) {
        // Normalize examId (remove ObjectId wrapper if present)
        String normalizedId = examId;
        if (examId.startsWith('ObjectId(')) {
          normalizedId = examId.substring(9, examId.length - 2);
        }
        await ExamService.updateExam(normalizedId, data, token);
        return true;
      } else if (type == 'DELETE' && examId != null) {
        // Normalize examId
        String normalizedId = examId;
        if (examId.startsWith('ObjectId(')) {
          normalizedId = examId.substring(9, examId.length - 2);
        }
        await ExamService.deleteExam(normalizedId, token);
        return true;
      }
      return false;
    } catch (e) {
      print('[CrudSync] Exam operation failed: $e');
      return false;
    }
  }

  static Future<bool> _syncClassOperation(
    String type,
    String? classId,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      if (type == 'CREATE') {
        await ClassService.createClass(data, token);
        return true;
      } else if (type == 'UPDATE' && classId != null) {
        await ClassService.updateClass(classId, data, token);
        return true;
      } else if (type == 'DELETE' && classId != null) {
        await ClassService.deleteClass(classId, token);
        return true;
      }
      return false;
    } catch (e) {
      print('[CrudSync] Class operation failed: $e');
      return false;
    }
  }

  static Future<bool> _syncStudentOperation(
    String type,
    String? studentId,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      if (type == 'CREATE') {
        await StudentService.addStudent(data, token);
        return true;
      } else if (type == 'UPDATE' && studentId != null) {
        await StudentService.updateStudent(studentId, data, token);
        return true;
      } else if (type == 'DELETE' && studentId != null) {
        await StudentService.deleteStudent(studentId, token);
        return true;
      }
      return false;
    } catch (e) {
      print('[CrudSync] Student operation failed: $e');
      return false;
    }
  }

  static Future<bool> _syncAnswerSheetOperation(
    String type,
    String? answerSheetId,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      if (type == 'CREATE') {
        await AnswerSheetService.createAnswerSheet(data, token);
        return true;
      } else if (type == 'DELETE' && answerSheetId != null) {
        // Normalize answerSheetId
        String normalizedId = answerSheetId;
        if (answerSheetId.startsWith('ObjectId(')) {
          normalizedId = answerSheetId.substring(9, answerSheetId.length - 2);
        }
        await AnswerSheetService.deleteAnswerSheet(normalizedId, token);
        return true;
      }
      return false;
    } catch (e) {
      print('[CrudSync] AnswerSheet operation failed: $e');
      return false;
    }
  }
}
