import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/class_provider.dart';
import '../providers/student_provider.dart';
import '../providers/answer_sheet_provider.dart';
import 'sync_service.dart';
import 'grading_service.dart';
import 'grade_cache_service.dart';
import 'answer_key_cache_service.dart';
import 'scanning_service.dart';
import 'crud_sync_service.dart';

class FullSyncResult {
  final int examsSynced;
  final int classesSynced;
  final int studentsSynced;
  final int answerSheetsSynced;
  final int gradesSynced;
  final int answerKeysSynced;
  final int pendingResultsSynced;
  final int pendingResultsFailed;
  final int crudOperationsSynced;
  final int crudOperationsFailed;
  final bool success;
  final String? error;

  FullSyncResult({
    required this.examsSynced,
    required this.classesSynced,
    required this.studentsSynced,
    required this.answerSheetsSynced,
    required this.gradesSynced,
    required this.answerKeysSynced,
    required this.pendingResultsSynced,
    required this.pendingResultsFailed,
    required this.crudOperationsSynced,
    required this.crudOperationsFailed,
    required this.success,
    this.error,
  });
}

class FullSyncService {
  static Future<FullSyncResult> performFullSync(BuildContext context) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      return FullSyncResult(
        examsSynced: 0,
        classesSynced: 0,
        studentsSynced: 0,
        answerSheetsSynced: 0,
        gradesSynced: 0,
        answerKeysSynced: 0,
        pendingResultsSynced: 0,
        pendingResultsFailed: 0,
        crudOperationsSynced: 0,
        crudOperationsFailed: 0,
        success: false,
        error: 'Not authenticated',
      );
    }

    try {
      final gradingSync = await SyncService.syncPendingResults(token);

      final crudSync = await CrudSyncService.syncPendingCrudOperations(token);

      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      final studentProvider = Provider.of<StudentProvider>(
        context,
        listen: false,
      );
      final answerSheetProvider = Provider.of<AnswerSheetProvider>(
        context,
        listen: false,
      );

      await examProvider.fetchExams(context);
      await classProvider.fetchClasses(context);
      await studentProvider.fetchStudents(context);
      await answerSheetProvider.fetchAnswerSheets(context);

      int gradesSynced = 0;
      int answerKeysSynced = 0;

      for (final exam in examProvider.exams) {
        var quizId = exam.id;
        if (quizId.startsWith('ObjectId(')) {
          quizId = quizId.substring(9, quizId.length - 2);
        }

        try {
          final grades = await GradingService.getGradesForQuiz(quizId, token);
          await GradeCacheService.cacheGradesForQuiz(quizId, grades);
          gradesSynced += grades.length;
        } catch (e) {
          print('[FullSync] Error syncing grades for $quizId: $e');
        }

        try {
          final hasKey = await GradingService.checkAnswerKey(quizId, token);
          if (hasKey) {
            final answerKey = await ScanningService.getAnswerKey(
              quizId: quizId,
              token: token,
            );
            if (answerKey != null) {
              await AnswerKeyCacheService.cacheAnswerKey(quizId, answerKey);
              answerKeysSynced++;
            }
          }
        } catch (e) {
          print('[FullSync] Error syncing answer key for $quizId: $e');
        }
      }

      return FullSyncResult(
        examsSynced: examProvider.exams.length,
        classesSynced: classProvider.classes.length,
        studentsSynced: studentProvider.students.length,
        answerSheetsSynced: answerSheetProvider.answerSheets.length,
        gradesSynced: gradesSynced,
        answerKeysSynced: answerKeysSynced,
        pendingResultsSynced: gradingSync.synced,
        pendingResultsFailed: gradingSync.failed,
        crudOperationsSynced: crudSync.synced,
        crudOperationsFailed: crudSync.failed,
        success: true,
      );
    } catch (e) {
      return FullSyncResult(
        examsSynced: 0,
        classesSynced: 0,
        studentsSynced: 0,
        answerSheetsSynced: 0,
        gradesSynced: 0,
        answerKeysSynced: 0,
        pendingResultsSynced: 0,
        pendingResultsFailed: 0,
        crudOperationsSynced: 0,
        crudOperationsFailed: 0,
        success: false,
        error: e.toString(),
      );
    }
  }
}
