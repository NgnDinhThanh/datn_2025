import 'package:bubblesheet_frontend/providers/answer_key_provider.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/providers/class_provider.dart';
import 'package:bubblesheet_frontend/providers/exam_provider.dart';
import 'package:bubblesheet_frontend/providers/student_provider.dart';
import 'package:bubblesheet_frontend/providers/answer_sheet_provider.dart';
import 'package:bubblesheet_frontend/providers/answer_sheet_form_provider.dart';
import 'package:bubblesheet_frontend/providers/scanning_provider.dart';
import 'package:bubblesheet_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';
import 'mobile/main_screen.dart';
import 'mobile/login_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox("answer_keys_cache");
  await Hive.openBox('grading_results_queue');
  await Hive.openBox('exams_cache');
  await Hive.openBox('classes_cache');
  await Hive.openBox('students_cache');

  // Debug: Log API baseUrl khi app khởi động
  ApiService.logBaseUrl();
  
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ClassProvider()),
      ChangeNotifierProvider(create: (_) => StudentProvider()),
      ChangeNotifierProvider(create: (_) => AnswerSheetProvider()),
      ChangeNotifierProvider(create: (_) => AnswerSheetFormProvider()),
      ChangeNotifierProvider(create: (_) => ExamProvider()),
      ChangeNotifierProvider(create: (_) => AnswerKeyProvider()),
      ChangeNotifierProvider(create: (_) => ScanningProvider()),
    ],
    child: const BubbleSheetMobileApp(),
  ));
}

class BubbleSheetMobileApp extends StatelessWidget {
  const BubbleSheetMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BubbleSheet Mobile',
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (authProvider.currentUser == null) {
            return const LoginScreen();
          }
          
          return const MainScreen();
        },
      ),
    );
  }
}
