import 'package:bubblesheet_frontend/models/exam_model.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/auth_helper.dart';
import 'package:bubblesheet_frontend/services/crud_operations_queue_service.dart';
import 'package:bubblesheet_frontend/services/exam_cache_service.dart';
import 'package:bubblesheet_frontend/services/exam_service.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

class ExamProvider with ChangeNotifier {
  List<ExamModel> _exams = [];
  bool _isLoading = false;
  String? _error;

  List<ExamModel> get exams => _exams;

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<void> fetchExams(BuildContext context) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cached = ExamCacheService.getCachedExams();
      if (cached != null && cached.isNotEmpty) {
        _exams = cached.map((json) => ExamModel.fromJson(json)).toList();
        // ✅ Merge với pending CRUD operations
        _mergePendingCrudOperations();
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('[ExamProvider] Error loading cache: $e');
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          _exams = await ExamService.getExams(token);
          await ExamCacheService.cacheExams(
            _exams.map((e) => e.toJson()).toList(),
          );
          // ✅ Merge với pending CRUD operations sau khi fetch từ API
          _mergePendingCrudOperations();
          _error = null;
          notifyListeners();
        } catch (e) {
          if (e is TokenExpiredException) {
            await handleTokenExpired(context);
            return;
          }
          if (_exams.isEmpty) {
            _error = 'No data. Please connect network.';
          }
        }
      } else {
        if (_exams.isEmpty) {
          _error = 'No data. Please connect network.';
        }
      }
    } else {
      if (_exams.isEmpty) {
        _error = 'Not authenticated and no cached data';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Merge pending CRUD operations vào danh sách exams hiện tại
  void _mergePendingCrudOperations() {
    try {
      final pendingOps = CrudOperationsQueueService.getPendingOperations()
          .where((op) => op['entity'] == 'Exam')
          .toList();

      for (var op in pendingOps) {
        final type = op['type'] as String;
        final entityId = op['entityId'] as String?;
        final data = Map<String, dynamic>.from(op['data'] as Map);

        if (type == 'CREATE') {
          // Thêm exam mới (nếu chưa có - check theo name và date để tránh duplicate)
          final examName = data['name'] ?? '';
          final examDate = data['date'] ?? DateTime.now().toIso8601String().substring(0, 10);
          if (examName.isNotEmpty && !_exams.any((e) => e.name == examName && e.date == examDate && e.id.startsWith('temp_'))) {
            _exams.add(ExamModel(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
              name: examName,
              answersheet: data['answersheet'] ?? '',
              date: examDate,
              class_codes: List<String>.from(data['class_codes'] ?? []),
              teacher_id: '', // Server sẽ tự động set từ token
            ));
          }
        } else if (type == 'UPDATE' && entityId != null) {
          // Cập nhật exam
          String normalizedId = entityId;
          if (entityId.startsWith('ObjectId(')) {
            normalizedId = entityId.substring(9, entityId.length - 2);
          }
          final index = _exams.indexWhere((e) => e.id == entityId || e.id == normalizedId);
          if (index != -1) {
            _exams[index] = ExamModel(
              id: _exams[index].id,
              name: data['name'] ?? _exams[index].name,
              answersheet: data['answersheet'] ?? _exams[index].answersheet,
              date: data['date'] ?? _exams[index].date,
              class_codes: List<String>.from(data['class_codes'] ?? _exams[index].class_codes),
              teacher_id: _exams[index].teacher_id,
            );
          }
        } else if (type == 'DELETE' && entityId != null) {
          // Xóa exam
          String normalizedId = entityId;
          if (entityId.startsWith('ObjectId(')) {
            normalizedId = entityId.substring(9, entityId.length - 2);
          }
          _exams.removeWhere((e) => e.id == entityId || e.id == normalizedId);
        }
      }
    } catch (e) {
      print('[ExamProvider] Error merging pending CRUD operations: $e');
    }
  }

  Future<String?> addExam(
      BuildContext context,
      Map<String, dynamic> examData,
      ) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      try {
        final response = await ExamService.createExam(examData, token);
        await fetchExams(context);
        return response['id'] ?? response['_id']?.toString();
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'CREATE',
          entity: 'Exam',
          entityId: null,
          data: examData,
        );
        // Optimistic UI: Add vào local list tạm thời
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        _exams.add(ExamModel(
          id: tempId,
          name: examData['name'] ?? '',
          answersheet: examData['answersheet'] ?? '',
          date: examData['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
          class_codes: List<String>.from(examData['class_codes'] ?? []),
          teacher_id: '', // Server sẽ tự động set từ token
        ));
        notifyListeners();
        return tempId;
      }
    } else {
      await CrudOperationsQueueService.addOperation(
        type: 'CREATE',
        entity: 'Exam',
        entityId: null,
        data: examData,
      );
      // Optimistic UI: Add vào local list tạm thời
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      _exams.add(ExamModel(
        id: tempId,
        name: examData['name'] ?? '',
        answersheet: examData['answersheet'] ?? '',
        date: examData['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
        class_codes: List<String>.from(examData['class_codes'] ?? []),
        teacher_id: '', // Server sẽ tự động set từ token
      ));
      notifyListeners();
      return tempId;
    }
  }

  Future<String?> updateExam(
    BuildContext context,
    String examId,
    Map<String, dynamic> examData,
  ) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // Normalize examId (remove ObjectId wrapper if present)
    String normalizedId = examId;
    if (examId.startsWith('ObjectId(')) {
      normalizedId = examId.substring(9, examId.length - 2);
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        final response = await ExamService.updateExam(normalizedId, examData, token);
        await fetchExams(context);
        return response['id'] ?? response['_id']?.toString();
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'UPDATE',
          entity: 'Exam',
          entityId: examId,
          data: examData,
        );
        // Optimistic UI: Update local list
        final index = _exams.indexWhere((e) => e.id == examId || e.id == normalizedId);
        if (index != -1) {
          _exams[index] = ExamModel(
            id: examId,
            name: examData['name'] ?? _exams[index].name,
            answersheet: examData['answersheet'] ?? _exams[index].answersheet,
            date: examData['date'] ?? _exams[index].date,
            class_codes: List<String>.from(examData['class_codes'] ?? _exams[index].class_codes),
            teacher_id: _exams[index].teacher_id,
          );
          notifyListeners();
        }
        return examId;
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'UPDATE',
        entity: 'Exam',
        entityId: examId,
        data: examData,
      );
      // Optimistic UI: Update local list
      final index = _exams.indexWhere((e) => e.id == examId || e.id == normalizedId);
      if (index != -1) {
        _exams[index] = ExamModel(
          id: examId,
          name: examData['name'] ?? _exams[index].name,
          answersheet: examData['answersheet'] ?? _exams[index].answersheet,
          date: examData['date'] ?? _exams[index].date,
          class_codes: List<String>.from(examData['class_codes'] ?? _exams[index].class_codes),
          teacher_id: _exams[index].teacher_id,
        );
        notifyListeners();
      }
      return examId;
    }
  }

  Future<void> deleteExam(BuildContext context, String examId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // Normalize examId (remove ObjectId wrapper if present)
    String normalizedId = examId;
    if (examId.startsWith('ObjectId(')) {
      normalizedId = examId.substring(9, examId.length - 2);
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        await ExamService.deleteExam(normalizedId, token);
        await fetchExams(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'DELETE',
          entity: 'Exam',
          entityId: examId,
          data: {},
        );
        // Optimistic UI: Remove từ local list
        _exams.removeWhere((e) => e.id == examId || e.id == normalizedId);
        notifyListeners();
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'DELETE',
        entity: 'Exam',
        entityId: examId,
        data: {},
      );
      // Optimistic UI: Remove từ local list
      _exams.removeWhere((e) => e.id == examId || e.id == normalizedId);
      notifyListeners();
    }
  }

  Future<void> deleteExams(BuildContext context, List<String> examIds) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    for (final id in examIds) {
      try {
        await ExamService.deleteExam(id, token);
      } catch (e) {
        // Có thể log hoặc bỏ qua lỗi từng lớp
      }
    }
    await fetchExams(context);
  }
}
