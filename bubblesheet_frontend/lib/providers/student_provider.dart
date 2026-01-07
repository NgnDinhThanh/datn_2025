import 'package:bubblesheet_frontend/models/student_model.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/api_service.dart';
import 'package:bubblesheet_frontend/services/student_cache_service.dart';
import 'package:bubblesheet_frontend/services/student_service.dart';
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
      _students = await ApiService.getStudents();

      await StudentCacheService.cacheStudents(
        _students.map((s) => s.toJson()).toList()
      );
    } catch (e) {
      final cached = StudentCacheService.getCachedStudents();
      if (cached != null && cached.isNotEmpty) {
        _students = cached.map((json) => Student.fromJson(json)).toList();
        print('[StudentProvider] Load ${_students.length} students from cache');
      } else {
        _error = 'Không có dữ liệu, Kiểm tra kết nối';
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> addStudent(BuildContext context, Map<String, dynamic> studentData) async {
    try {
      final result = await ApiService.addStudent(studentData);
      await fetchStudents(context);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<Student> fetchStudentById
      (BuildContext context, String studentId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    return await StudentService.fetchStudentById(studentId, token);
  }

  Future<void> updateStudent(
      BuildContext context,
      String studentId,
      Map<String, dynamic> data
      ) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    await StudentService.updateStudent(studentId, data, token);
    await fetchStudents(context);
  }

  Future<void> deleteStudent(BuildContext context, String studentId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    await StudentService.deleteStudent(studentId, token);
    await fetchStudents(context);
  }
}