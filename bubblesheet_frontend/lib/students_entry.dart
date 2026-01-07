import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/students/student_list_screen.dart' as web;
import 'mobile/students_screen.dart' as mobile;

class StudentsEntry extends StatelessWidget {
  const StudentsEntry({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const web.StudentListScreen();
    } else {
      return const mobile.StudentsScreen();
    }
  }
} 