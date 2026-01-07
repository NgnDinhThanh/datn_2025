import 'dart:convert';
import 'package:bubblesheet_frontend/models/class_model.dart';
import 'package:bubblesheet_frontend/models/student_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../mobile/login_screen.dart';

class ApiService {
  // Danh sách IP cho mobile (thử theo thứ tự)
  static final List<String> _mobileBaseUrls = [
    'http://192.168.99.114:8000/api',  // IP chính
    'http://192.168.99.108:8000/api',  // IP phụ (thay đổi theo mạng của bạn)
  ];

  // BaseUrl hiện tại đang sử dụng
  static String? _currentBaseUrl;

  static String? _token;
  static BuildContext? _context;

  // Lấy baseUrl hiện tại
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    // Nếu chưa có baseUrl, dùng IP đầu tiên
    _currentBaseUrl ??= _mobileBaseUrls.first;
    return _currentBaseUrl!;
  }

  // Debug: Log baseUrl khi app khởi động
  static void logBaseUrl() {
    // Logs removed for production
  }

  // Test kết nối với một baseUrl
  static Future<bool> _testConnection(String baseUrl) async {
    try {
      final url = Uri.parse('$baseUrl/users/login/');
      final response = await http.get(url).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      // Nếu có response (kể cả 405 Method Not Allowed) nghĩa là server đang chạy
      return response.statusCode != 0;
    } catch (e) {
      return false;
    }
  }

  // Tự động tìm IP đang hoạt động (public method để có thể gọi từ bên ngoài)
  static Future<String?> findWorkingBaseUrl() async {
    for (final url in _mobileBaseUrls) {
      if (await _testConnection(url)) {
        _currentBaseUrl = url;
        return url;
      }
    }
    return null;
  }

  // Private method cho internal use
  static Future<String?> _findWorkingBaseUrl() async {
    return await findWorkingBaseUrl();
  }

  // Reset baseUrl về IP đầu tiên (dùng khi cần test lại)
  static void resetBaseUrl() {
    _currentBaseUrl = null;
  }

  // Thử kết nối lại với IP khác nếu request hiện tại fail
  static Future<http.Response> _retryWithFallback(
      Future<http.Response> Function(String baseUrl) requestFn,
      ) async {
    // Thử với baseUrl hiện tại
    try {
      final response = await requestFn(baseUrl);
      // Nếu thành công hoặc lỗi không phải connection error, return luôn
      if (response.statusCode != 0) {
        return response;
      }
    } catch (e) {
      // Request failed, trying fallback
    }

    // Nếu fail, thử tìm IP khác
    final workingUrl = await _findWorkingBaseUrl();
    if (workingUrl != null && workingUrl != _currentBaseUrl) {
      _currentBaseUrl = workingUrl;
      return await requestFn(workingUrl);
    }

    // Nếu không tìm thấy IP nào, throw error
    throw Exception('Cannot connect to server. Please check your network connection.');
  }

  static void setContext(BuildContext context) {
    _context = context;
  }

  static void setToken(String? token) {
    _token = token;
  }

  // Đăng nhập
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _retryWithFallback((baseUrl) async {
      final url = Uri.parse('$baseUrl/users/login/');
      return await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
    });
    return _processResponse(response);
  }

  // Đăng ký
  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await _retryWithFallback((baseUrl) async {
      final url = Uri.parse('$baseUrl/users/');
      return await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'email': email, 'password': password}),
      );
    });
    return _processResponse(response);
  }

  // Lấy danh sách sinh viên
  static Future<List<Student>> getStudents() async {
    final response = await _retryWithFallback((baseUrl) async {
      return await http.get(
        Uri.parse('$baseUrl/students/'),
        headers: _getAuthHeaders(),
      );
    });
    final handledResponse = await _handleResponse(response);
    if (handledResponse.statusCode == 200) {
      try {
        final List<dynamic> data = json.decode(handledResponse.body);
        print('[ApiService] Response body decoded: ${data.length} items');
        final students = data.map((json) {
          try {
            return Student.fromJson(json);
          } catch (e) {
            print('[ApiService] Error parsing student JSON: $e');
            print('[ApiService] JSON data: $json');
            rethrow;
          }
        }).toList();
        print('[ApiService] Successfully parsed ${students.length} students');
        return students;
      } catch (e) {
        print('[ApiService] Error parsing response: $e');
        print('[ApiService] Response body: ${handledResponse.body}');
        rethrow;
      }
    } else {
      throw Exception('Failed to load students');
    }
  }

  // Thêm mới sinh viên
  static Future<Map<String, dynamic>> addStudent(Map<String, dynamic> data) async {
    final response = await _retryWithFallback((baseUrl) async {
      return await http.post(
        Uri.parse('$baseUrl/students/'),
        headers: _getAuthHeaders(),
        body: jsonEncode(data),
      );
    });
    final handledResponse = await _handleResponse(response);
    return _processResponse(handledResponse);
  }

  // Hàm lấy headers có token
  static Map<String, String> _getAuthHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Xử lý response chung
  static Map<String, dynamic> _processResponse(http.Response response) {
    final Map<String, dynamic> result = {};
    result['statusCode'] = response.statusCode;
    try {
      result['body'] = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      result['body'] = response.body;
    }
    return result;
  }

  // Xử lý response và kiểm tra token hết hạn
  static Future<http.Response> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      // Token hết hạn, logout và chuyển về màn hình login
      if (_context != null) {
        await Provider.of<AuthProvider>(_context!, listen: false).logout();
        if (_context!.mounted) {
          Navigator.of(_context!).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        }
      }
    }
    return response;
  }
}