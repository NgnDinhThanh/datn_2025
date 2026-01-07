import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _currentUser;
  String? _token;
  bool _isLoading = true;

  String? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('currentUser');
    _token = prefs.getString('token');
    ApiService.setToken(_token);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrentUser(String user, String token) async {
    _currentUser = user;
    _token = token;
    ApiService.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUser', user);
    await prefs.setString('token', token);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');
    await prefs.remove('token');
    notifyListeners();
  }
}