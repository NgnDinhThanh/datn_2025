import 'package:bubblesheet_frontend/models/student_model.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/api_service.dart';
import 'package:bubblesheet_frontend/services/auth_helper.dart';
import 'package:bubblesheet_frontend/services/student_cache_service.dart';
import 'package:bubblesheet_frontend/services/student_service.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:bubblesheet_frontend/services/crud_operations_queue_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

class StudentProvider with ChangeNotifier {
  List<Student> _students = [];
  bool _isLoading = false;
  String? _error;

  List<Student> get students => _students;

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<void> fetchStudents(BuildContext context) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cached = StudentCacheService.getCachedStudents();
      if (cached != null && cached.isNotEmpty) {
        _students = cached.map((json) => Student.fromJson(json)).toList();
        // ✅ Merge với pending CRUD operations
        _mergePendingCrudOperations();
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('[StudentProvider] Error loading cache: $e');
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          _students = await ApiService.getStudents();
          await StudentCacheService.cacheStudents(
            _students.map((s) => s.toJson()).toList(),
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
          if (_students.isEmpty) {
            _error = 'No data. Please connect network';
          }
        }
      } else {
        if (_students.isEmpty) {
          _error = 'No data. Please connect network.';
        }
      }
    } else {
      if (_students.isEmpty) {
        _error = 'Not authenticated and no cached data';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Merge pending CRUD operations vào danh sách students hiện tại
  void _mergePendingCrudOperations() {
    try {
      final pendingOps = CrudOperationsQueueService.getPendingOperations()
          .where((op) => op['entity'] == 'Student')
          .toList();

      for (var op in pendingOps) {
        final type = op['type'] as String;
        final entityId = op['entityId'] as String?;
        final data = Map<String, dynamic>.from(op['data'] as Map);

        if (type == 'CREATE') {
          // Thêm student mới (nếu chưa có)
          final studentId = data['student_id'] as String? ?? '';
          if (studentId.isNotEmpty && !_students.any((s) => s.studentId == studentId)) {
            _students.add(Student(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
              studentId: studentId,
              firstName: data['first_name'] ?? '',
              lastName: data['last_name'] ?? '',
              classCodes: List<String>.from(data['class_codes'] ?? []),
            ));
          }
        } else if (type == 'UPDATE' && entityId != null) {
          // Cập nhật student
          final index = _students.indexWhere((s) => s.studentId == entityId);
          if (index != -1) {
            _students[index] = Student(
              id: _students[index].id,
              studentId: entityId,
              firstName: data['first_name'] ?? _students[index].firstName,
              lastName: data['last_name'] ?? _students[index].lastName,
              classCodes: List<String>.from(data['class_codes'] ?? _students[index].classCodes),
            );
          }
        } else if (type == 'DELETE' && entityId != null) {
          // Xóa student
          _students.removeWhere((s) => s.studentId == entityId);
        }
      }
    } catch (e) {
      print('[StudentProvider] Error merging pending CRUD operations: $e');
    }
  }

  Future<Map<String, dynamic>> addStudent(
    BuildContext context,
    Map<String, dynamic> studentData,
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
        final result = await ApiService.addStudent(studentData);
        await fetchStudents(context);
        return result;
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'CREATE',
          entity: 'Student',
          entityId: null,
          data: studentData,
        );
        // Optimistic UI: Add vào local list
        _students.add(Student(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          studentId: studentData['student_id'] ?? '',
          firstName: studentData['first_name'] ?? '',
          lastName: studentData['last_name'] ?? '',
          classCodes: List<String>.from(studentData['class_codes'] ?? []),
        ));
        notifyListeners();
        return {'id': 'temp_${DateTime.now().millisecondsSinceEpoch}'};
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'CREATE',
        entity: 'Student',
        entityId: null,
        data: studentData,
      );
      // Optimistic UI: Add vào local list
      _students.add(Student(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentData['student_id'] ?? '',
        firstName: studentData['first_name'] ?? '',
        lastName: studentData['last_name'] ?? '',
        classCodes: List<String>.from(studentData['class_codes'] ?? []),
      ));
      notifyListeners();
      return {'id': 'temp_${DateTime.now().millisecondsSinceEpoch}'};
    }
  }

  Future<Student> fetchStudentById(
    BuildContext context,
    String studentId,
  ) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    return await StudentService.fetchStudentById(studentId, token);
  }

  Future<void> updateStudent(
    BuildContext context,
    String studentId,
    Map<String, dynamic> data,
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
        await StudentService.updateStudent(studentId, data, token);
        await fetchStudents(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'UPDATE',
          entity: 'Student',
          entityId: studentId,
          data: data,
        );
        // Optimistic UI: Update local list
        final index = _students.indexWhere((s) => s.studentId == studentId);
        if (index != -1) {
          _students[index] = Student(
            id: _students[index].id,
            studentId: studentId,
            firstName: data['first_name'] ?? _students[index].firstName,
            lastName: data['last_name'] ?? _students[index].lastName,
            classCodes: List<String>.from(data['class_codes'] ?? _students[index].classCodes),
          );
          notifyListeners();
        }
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'UPDATE',
        entity: 'Student',
        entityId: studentId,
        data: data,
      );
      // Optimistic UI: Update local list
      final index = _students.indexWhere((s) => s.studentId == studentId);
      if (index != -1) {
        _students[index] = Student(
          id: _students[index].id,
          studentId: studentId,
          firstName: data['first_name'] ?? _students[index].firstName,
          lastName: data['last_name'] ?? _students[index].lastName,
          classCodes: List<String>.from(data['class_codes'] ?? _students[index].classCodes),
        );
        notifyListeners();
      }
    }
  }

  Future<void> deleteStudent(BuildContext context, String studentId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // ✅ Check network
    final hasNetwork = await SyncService.hasNetworkConnection();

    if (hasNetwork) {
      // ✅ Online: Gọi API ngay
      try {
        await StudentService.deleteStudent(studentId, token);
        await fetchStudents(context);
      } catch (e) {
        // Nếu API fail, queue lại
        await CrudOperationsQueueService.addOperation(
          type: 'DELETE',
          entity: 'Student',
          entityId: studentId,
          data: {},
        );
        // Optimistic UI: Remove từ local list
        _students.removeWhere((s) => s.studentId == studentId);
        notifyListeners();
      }
    } else {
      // ✅ Offline: Queue operation
      await CrudOperationsQueueService.addOperation(
        type: 'DELETE',
        entity: 'Student',
        entityId: studentId,
        data: {},
      );
      // Optimistic UI: Remove từ local list
      _students.removeWhere((s) => s.studentId == studentId);
      notifyListeners();
    }
  }
}
