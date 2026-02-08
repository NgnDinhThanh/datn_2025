import 'dart:convert';
import 'package:bubblesheet_frontend/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:bubblesheet_frontend/services/api_service.dart';
import 'auth_helper.dart';

class UserService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<List<AdminUserItem>> getAdminUsers(String token) async {
    final url = Uri.parse('$baseUrl/users/admin/users/');
    final response = await http
        .get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => AdminUserItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load users: ${response.statusCode}');
  }

  static Future<AdminStats> getAdminStats(String token) async {
    final url = Uri.parse('$baseUrl/users/admin/stats/');
    final response = await http
        .get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));
    checkAuthError(response.statusCode, response.body);
    if (response.statusCode == 200) {
      return AdminStats.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Failed to load stats: ${response.statusCode}');
  }

  static Future<UserProfileData> getCurrentUserProfile(String token) async {
    try {
      final url = Uri.parse('$baseUrl/users/me/');
      print('[UserService] Getting current user profile');

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('[UserService] Timeout getting user profile');
              throw Exception('Request timeout');
            },
          );

      print('[UserService] Get user profile response: ${response.statusCode}');

      checkAuthError(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = UserProfileData.fromJson(data);
        print('[UserService] Loaded user profile: ${profile.username}');
        return profile;
      } else {
        print(
          '[UserService] Get user profile failed: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to load user profile: Status ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('[UserService] Error getting user profile: $e');
      print('[UserService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
