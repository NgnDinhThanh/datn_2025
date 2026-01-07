import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/quizzes/quizz_list_screen.dart' as web;
import 'mobile/quizz_screen.dart' as mobile;

class QuizzesEntry extends StatelessWidget {
  const QuizzesEntry({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const web.QuizzListScreen();
    } else {
      return const mobile.QuizzesScreen();
    }
  }
} 