import 'package:bubblesheet_frontend/providers/answer_key_provider.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/providers/class_provider.dart';
import 'package:bubblesheet_frontend/providers/exam_provider.dart';
import 'package:bubblesheet_frontend/providers/student_provider.dart';
import 'package:bubblesheet_frontend/providers/answer_sheet_provider.dart';
import 'package:bubblesheet_frontend/providers/answer_sheet_form_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'router.dart' show BubbleSheetApp;

void main() {
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ClassProvider()),
      ChangeNotifierProvider(create: (_) => StudentProvider()),
      ChangeNotifierProvider(create: (_) => AnswerSheetProvider()),
      ChangeNotifierProvider(create: (_) => AnswerSheetFormProvider()),
      ChangeNotifierProvider(create: (_) => ExamProvider()),
      ChangeNotifierProvider(create: (_) => AnswerKeyProvider()),
    ],
    child: const BubbleSheetApp(),
  ));
}

