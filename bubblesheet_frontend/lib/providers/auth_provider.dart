import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _currentUser;
  String? _token;
  bool _isAdmin = false;
  bool _isLoading = true;

  String? get currentUser => _currentUser;

  String? get token => _token;

  bool get isAdmin => _isAdmin;

  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('currentUser');
    _token = prefs.getString('token');
    _isAdmin = prefs.getBool('isAdmin') ?? false;
    ApiService.setToken(_token);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrentUser(
    String user,
    String token, {
    bool isAdmin = false,
  }) async {
    _currentUser = user;
    _token = token;
    _isAdmin = isAdmin;
    ApiService.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUser', user);
    await prefs.setString('token', token);
    await prefs.setBool('isAdmin', isAdmin);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    _isAdmin = false;
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');
    await prefs.remove('token');
    await prefs.remove('isAdmin');
    notifyListeners();
  }
}
