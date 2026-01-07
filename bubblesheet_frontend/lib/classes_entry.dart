import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/classes/class_list_screen.dart' as web;
import 'mobile/classes_screen.dart' as mobile;

class ClassesEntry extends StatelessWidget {
  const ClassesEntry({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const web.ClassListScreen();
    } else {
      return const mobile.ClassesScreen();
    }
  }
} 