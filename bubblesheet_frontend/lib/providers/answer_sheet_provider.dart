import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/answer_sheet_cache_service.dart';
import 'package:bubblesheet_frontend/services/auth_helper.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:bubblesheet_frontend/services/crud_operations_queue_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/answer_sheet_model.dart';
import '../services/answer_sheet_service.dart';

class AnswerSheetProvider extends ChangeNotifier {
  List<AnswerSheet> _answerSheets = [];
  bool _isLoading = false;
  String? _error;

  List<AnswerSheet> get answerSheets => _answerSheets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAnswerSheets(BuildContext context) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final cached = AnswerSheetCacheService.getCachedAnswerSheets();
      if (cached != null && cached.isNotEmpty) {
        _answerSheets = cached.map((json) => AnswerSheet.fromJson(json)).toList();
        // ✅ Merge với pending CRUD operations
        _mergePendingCrudOperations();
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('[AnswerSheetProvider] Error loading cache: $e');
    }
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          final newSheets = await AnswerSheetService.getAnswerSheets(token);
          await AnswerSheetCacheService.cacheAnswerSheets(newSheets.map((a) => a.toJson()).toList());
          _answerSheets = newSheets;
          // ✅ Merge với pending CRUD operations sau khi fetch từ API
          _mergePendingCrudOperations();
          _error = null;
          notifyListeners();
        } catch (e) {
          if (e is TokenExpiredException) {
            await handleTokenExpired(context);
            return;
          }
          if (_answerSheets.isEmpty) {
            _error = 'No data. Please connect network';
          }
        }
      } else {
        if (_answerSheets.isEmpty) {
          _error = 'No data. Please connect network.';
        }
      }
    } else {
      if (_answerSheets.isEmpty) {
        _error = 'Not authenticated and no cached data';
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Merge pending CRUD operations vào danh sách answer sheets hiện tại
  void _mergePendingCrudOperations() {
    try {
      final pendingOps = CrudOperationsQueueService.getPendingOperations()
          .where((op) => op['entity'] == 'AnswerSheet')
          .toList();

      for (var op in pendingOps) {
        final type = op['type'] as String;
        final entityId = op['entityId'] as String?;
        final data = Map<String, dynamic>.from(op['data'] as Map);

        if (type == 'CREATE') {
          // Thêm answer sheet mới (nếu chưa có)
          final name = data['name'] as String? ?? '';
          if (name.isNotEmpty && !_answerSheets.any((a) => a.name == name && a.id.startsWith('temp_'))) {
            _answerSheets.add(AnswerSheet(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              createdAt: DateTime.now(),
              numQuestions: data['num_questions'] ?? 0,
              numOptions: data['num_options'] ?? 4,
              studentIdDigits: data['student_id_digits'] ?? 0,
              examIdDigits: data['exam_id_digits'] ?? 0,
              classIdDigits: data['class_id_digits'] ?? 0,
              filePdf: '',
              fileJson: '',
              filePreview: '',
            ));
          }
        } else if (type == 'DELETE' && entityId != null) {
          // Xóa answer sheet
          String normalizedId = entityId;
          if (entityId.startsWith('ObjectId(')) {
            normalizedId = entityId.substring(9, entityId.length - 2);
          }
          _answerSheets.removeWhere((a) => a.id == entityId || a.id == normalizedId);
        }
      }
    } catch (e) {
      print('[AnswerSheetProvider] Error merging pending CRUD operations: $e');
    }
  }

  Future<void> createAnswerSheet(BuildContext context, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      _isLoading = false;
      _error = 'Not authenticated';
      notifyListeners();
      return;
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        await AnswerSheetService.createAnswerSheet(data, token);
        await fetchAnswerSheets(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'CREATE',
          entity: 'AnswerSheet',
          entityId: null,
          data: data,
        );
        // Optimistic UI: Add vào local list
        _answerSheets.add(AnswerSheet(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          name: data['name'] ?? '',
          createdAt: DateTime.now(),
          numQuestions: data['num_questions'] ?? 0,
          numOptions: data['num_options'] ?? 4,
          studentIdDigits: data['student_id_digits'] ?? 0,
          examIdDigits: data['exam_id_digits'] ?? 0,
          classIdDigits: data['class_id_digits'] ?? 0,
          filePdf: '',
          fileJson: '',
          filePreview: '',
        ));
        _error = null;
        notifyListeners();
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'CREATE',
        entity: 'AnswerSheet',
        entityId: null,
        data: data,
      );
      // Optimistic UI: Add vào local list
      _answerSheets.add(AnswerSheet(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        name: data['name'] ?? '',
        createdAt: DateTime.now(),
        numQuestions: data['num_questions'] ?? 0,
        numOptions: data['num_options'] ?? 4,
        studentIdDigits: data['student_id_digits'] ?? 0,
        examIdDigits: data['exam_id_digits'] ?? 0,
        classIdDigits: data['class_id_digits'] ?? 0,
        filePdf: '',
        fileJson: '',
        filePreview: '',
      ));
      _error = null;
      notifyListeners();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteAnswerSheet(BuildContext context, String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      _isLoading = false;
      _error = 'Not authenticated';
      notifyListeners();
      return;
    }

    // Normalize id (remove ObjectId wrapper if present)
    String normalizedId = id;
    if (id.startsWith('ObjectId(')) {
      normalizedId = id.substring(9, id.length - 2);
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        await AnswerSheetService.deleteAnswerSheet(normalizedId, token);
        await fetchAnswerSheets(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'DELETE',
          entity: 'AnswerSheet',
          entityId: id,
          data: {},
        );
        // Optimistic UI: Remove từ local list
        _answerSheets.removeWhere((a) => a.id == id || a.id == normalizedId);
        _error = null;
        notifyListeners();
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'DELETE',
        entity: 'AnswerSheet',
        entityId: id,
        data: {},
      );
      // Optimistic UI: Remove từ local list
      _answerSheets.removeWhere((a) => a.id == id || a.id == normalizedId);
      _error = null;
      notifyListeners();
    }

    _isLoading = false;
    notifyListeners();
  }

// Thêm các hàm create, delete, ... nếu cần
}
