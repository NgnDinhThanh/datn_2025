import 'dart:convert';

import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/class_cache_service.dart';
import 'package:bubblesheet_frontend/services/class_service.dart';
import 'package:bubblesheet_frontend/services/auth_helper.dart';
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

  Map<String, String> get classCodeToName => {for (var c in _classes) c.class_code: c.class_name};

  Future<void> fetchClasses(BuildContext context) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      _classes = await ClassService.getClasses(token);

      await ClassCacheService.cacheClasses(
        _classes.map((c) => c.toJson()).toList()
      );
    } catch (e) {
      if (e is TokenExpiredException) {
        await handleTokenExpired(context);
        return;
      }

      final cached = ClassCacheService.getCachedClasses();

      if (cached != null && cached.isNotEmpty) {
        _classes = cached.map((json) => ClassModel.fromJson(json)).toList();
        print('[ClassProvider] Load ${_classes.length} classes from cache');
      } else {
        _error = 'Không có dữ liệu, Kiểm tra kết nối';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addClass(BuildContext context, Map<String, dynamic> classData) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await ClassService.createClass(classData, token);
      await fetchClasses(context);
    } catch (e) {
      throw e;
    }
  }

  Future<void> updateClass(BuildContext context, String classId, Map<String, dynamic> classData) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await ClassService.updateClass(classId, classData, token);
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteClass(BuildContext context, String classId) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await ClassService.deleteClass(classId, token);
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteClasses(BuildContext context, List<String> classCodes) async {
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
