import 'package:bubblesheet_frontend/screens/classes/class_list_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/main_layout.dart' as web;
import 'mobile/main_screen.dart' as mobile;

Widget buildMainScreen() {
  if (kIsWeb) {
    // Not under GoRouter when using navigation.dart, so pass a fallback path
    return const web.MainLayout(child: ClassListScreen(), currentPath: '/classes');
  } else {
    return const mobile.MainScreen();
  }
} 