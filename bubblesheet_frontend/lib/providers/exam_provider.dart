import 'package:bubblesheet_frontend/models/exam_model.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/exam_cache_service.dart';
import 'package:bubblesheet_frontend/services/exam_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

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
      // 1. Thử fetch từ server
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      _exams = await ExamService.getExams(token);

      // 2. Nếu thành công → Cache lại
      await ExamCacheService.cacheExams(
          _exams.map((e) => e.toJson()).toList()
      );

    } catch (e) {
      // 3. Nếu fail → Load từ cache
      final cached = ExamCacheService.getCachedExams();

      if (cached != null && cached.isNotEmpty) {
        _exams = cached.map((json) => ExamModel.fromJson(json)).toList();
        print('[ExamProvider] Loaded ${_exams.length} exams from cache');
      } else {
        _error = 'Không có dữ liệu. Vui lòng kết nối mạng.';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> addExam(
    BuildContext context,
    Map<String, dynamic> examData,
  ) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final response = await ExamService.createExam(examData, token);
      await fetchExams(context);
      return response['id'] ?? response['_id']?.toString();
    } catch (e) {
      throw e;
    }
  }

  Future<String?> updateExam(
    BuildContext context,
    String examId,
    Map<String, dynamic> examData,
  ) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final response = await ExamService.updateExam(examId, examData, token);
      await fetchExams(context);
      return response['id'] ?? response['_id']?.toString();
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteExam(BuildContext context, String examId) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await ExamService.deleteExam(examId, token);
    } catch (e) {
      throw e;
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
