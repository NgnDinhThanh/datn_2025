import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart' as web;
import 'mobile/login_screen.dart' as mobile;

class LoginEntry extends StatelessWidget {
  const LoginEntry({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const web.LoginScreen();
    } else {
      return const mobile.LoginScreen();
    }
  }
} 