import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/users/user_screen.dart' as web;
import 'mobile/my_account_screen.dart' as mobile;

class MyAccountEntry extends StatelessWidget {
  const MyAccountEntry({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const web.UserScreen();
    } else {
      return const mobile.MyAccountScreen();
    }
  }
} 