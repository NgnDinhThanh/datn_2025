import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../mobile/login_screen.dart';

/// Custom exception for token expired
class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException(this.message);
  @override
  String toString() => message;
}

/// Helper function to check if response is 401 and throw TokenExpiredException
void checkAuthError(int statusCode, String? errorBody) {
  if (statusCode == 401) {
    throw TokenExpiredException('Token expired or invalid. Please login again.');
  }
}

/// Helper function to handle token expired - logout and redirect to login
Future<void> handleTokenExpired(BuildContext context) async {
  await Provider.of<AuthProvider>(context, listen: false).logout();
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

