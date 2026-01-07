import 'dart:convert';

import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/class_cache_service.dart';
import 'package:bubblesheet_frontend/services/class_service.dart';
import 'package:bubblesheet_frontend/services/auth_helper.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:bubblesheet_frontend/services/crud_operations_queue_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';

class ClassProvider with ChangeNotifier {
  List<ClassModel> _classes = [];
  bool _isLoading = false;
  String? _error;

  List<ClassModel> get classes => _classes;

  bool get isLoading => _isLoading;

  String? get error => _error;

  Map<String, String> get classCodeToName => {
    for (var c in _classes) c.class_code: c.class_name,
  };

  Future<void> fetchClasses(BuildContext context) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cached = ClassCacheService.getCachedClasses();
      if (cached != null && cached.isNotEmpty) {
        _classes = cached.map((json) => ClassModel.fromJson(json)).toList();
        // ✅ Merge với pending CRUD operations
        _mergePendingCrudOperations();
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('[ClassProvider] Error loading cache: $e');
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          _classes = await ClassService.getClasses(token);
          await ClassCacheService.cacheClasses(
            _classes.map((c) => c.toJson()).toList(),
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
          if (_classes.isEmpty) {
            _error = 'Không có dữ liệu, Kiểm tra kết nối';
          }
        }
      } else {
        if (_classes.isEmpty) {
          _error = 'Không có dữ liệu, Kiểm tra kết nối';
        }
      }
    } else {
      if (_classes.isEmpty) {
        _error = 'Not authenticated and no cached data';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Merge pending CRUD operations vào danh sách classes hiện tại
  void _mergePendingCrudOperations() {
    try {
      final pendingOps = CrudOperationsQueueService.getPendingOperations()
          .where((op) => op['entity'] == 'Class')
          .toList();

      for (var op in pendingOps) {
        final type = op['type'] as String;
        final entityId = op['entityId'] as String?;
        final data = Map<String, dynamic>.from(op['data'] as Map);

        if (type == 'CREATE') {
          // Thêm class mới (nếu chưa có - check theo class_code để tránh duplicate)
          final classCode = data['class_code'] as String? ?? '';
          if (classCode.isNotEmpty && !_classes.any((c) => c.class_code == classCode)) {
            _classes.add(ClassModel(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
              class_code: classCode,
              class_name: data['class_name'] ?? '',
              student_count: 0,
              teacher_id: '', // Server sẽ tự động set từ token
              exam_ids: [],
              student_ids: [],
            ));
          }
        } else if (type == 'UPDATE' && entityId != null) {
          // Cập nhật class
          final index = _classes.indexWhere((c) => c.class_code == entityId);
          if (index != -1) {
            _classes[index] = ClassModel(
              id: _classes[index].id,
              class_code: entityId,
              class_name: data['class_name'] ?? _classes[index].class_name,
              student_count: _classes[index].student_count,
              teacher_id: _classes[index].teacher_id,
              exam_ids: _classes[index].exam_ids,
              student_ids: _classes[index].student_ids,
            );
          }
        } else if (type == 'DELETE' && entityId != null) {
          // Xóa class
          _classes.removeWhere((c) => c.class_code == entityId);
        }
      }
    } catch (e) {
      print('[ClassProvider] Error merging pending CRUD operations: $e');
    }
  }

  Future<void> addClass(
    BuildContext context,
    Map<String, dynamic> classData,
  ) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        await ClassService.createClass(classData, token);
        await fetchClasses(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'CREATE',
          entity: 'Class',
          entityId: null,
          data: classData,
        );
        // Optimistic UI: Add vào local list
        _classes.add(ClassModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          class_code: classData['class_code'] ?? '',
          class_name: classData['class_name'] ?? '',
          student_count: 0,
          teacher_id: '', // Server sẽ tự động set từ token
          exam_ids: [],
          student_ids: [],
        ));
        notifyListeners();
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'CREATE',
        entity: 'Class',
        entityId: null,
        data: classData,
      );
      // Optimistic UI: Add vào local list
      _classes.add(ClassModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        class_code: classData['class_code'] ?? '',
        class_name: classData['class_name'] ?? '',
        student_count: 0,
        teacher_id: '', // Server sẽ tự động set từ token
        exam_ids: [],
        student_ids: [],
      ));
      notifyListeners();
    }
  }

  Future<void> updateClass(
    BuildContext context,
    String classId,
    Map<String, dynamic> classData,
  ) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        await ClassService.updateClass(classId, classData, token);
        await fetchClasses(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'UPDATE',
          entity: 'Class',
          entityId: classId,
          data: classData,
        );
        // Optimistic UI: Update local list
        final index = _classes.indexWhere((c) => c.class_code == classId);
        if (index != -1) {
          _classes[index] = ClassModel(
            id: _classes[index].id,
            class_code: classId,
            class_name: classData['class_name'] ?? _classes[index].class_name,
            student_count: _classes[index].student_count,
            teacher_id: _classes[index].teacher_id,
            exam_ids: _classes[index].exam_ids,
            student_ids: _classes[index].student_ids,
          );
          notifyListeners();
        }
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'UPDATE',
        entity: 'Class',
        entityId: classId,
        data: classData,
      );
      // Optimistic UI: Update local list
      final index = _classes.indexWhere((c) => c.class_code == classId);
      if (index != -1) {
        _classes[index] = ClassModel(
          id: _classes[index].id,
          class_code: classId,
          class_name: classData['class_name'] ?? _classes[index].class_name,
          student_count: _classes[index].student_count,
          teacher_id: _classes[index].teacher_id,
          exam_ids: _classes[index].exam_ids,
          student_ids: _classes[index].student_ids,
        );
        notifyListeners();
      }
    }
  }

  Future<void> deleteClass(BuildContext context, String classId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        await ClassService.deleteClass(classId, token);
        await fetchClasses(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'DELETE',
          entity: 'Class',
          entityId: classId,
          data: {},
        );
        // Optimistic UI: Remove từ local list
        _classes.removeWhere((c) => c.class_code == classId);
        notifyListeners();
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'DELETE',
        entity: 'Class',
        entityId: classId,
        data: {},
      );
      // Optimistic UI: Remove từ local list
      _classes.removeWhere((c) => c.class_code == classId);
      notifyListeners();
    }
  }

  Future<void> deleteClasses(
    BuildContext context,
    List<String> classCodes,
  ) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    for (final code in classCodes) {
      try {
        await ClassService.deleteClass(code, token);
      } catch (e) {
        // Có thể log hoặc bỏ qua lỗi từng lớp
      }
    }
    await fetchClasses(context);
  }
}
