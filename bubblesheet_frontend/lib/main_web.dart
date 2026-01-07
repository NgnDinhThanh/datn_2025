import 'package:bubblesheet_frontend/providers/answer_key_provider.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/providers/class_provider.dart';
import 'package:bubblesheet_frontend/providers/exam_provider.dart';
import 'package:bubblesheet_frontend/providers/student_provider.dart';
import 'package:bubblesheet_frontend/providers/answer_sheet_provider.dart';
import 'package:bubblesheet_frontend/providers/answer_sheet_form_provider.dart';
import 'package:bubblesheet_frontend/screens/quizzes/quiz_detail_screen.dart';
import 'package:bubblesheet_frontend/screens/quizzes/quiz_edit_answer_key_screen.dart';
import 'package:bubblesheet_frontend/screens/quizzes/quiz_form_screen.dart';
import 'package:bubblesheet_frontend/screens/quizzes/quizz_list_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_layout.dart';
import 'screens/classes/class_list_screen.dart';
import 'screens/classes/class_add_screen.dart';
import 'screens/students/student_list_screen.dart';
import 'screens/users/user_screen.dart';
import 'screens/classes/class_edit_screen.dart';
import 'screens/classes/class_edit_students_screen.dart';
import 'screens/students/student_form_screen.dart';
import 'screens/students/student_import_screen.dart';
import 'screens/answer_sheets/answer_sheet_list_screen.dart';
import 'screens/answer_sheets/answer_sheet_form_name_screen.dart';
import 'screens/answer_sheets/answer_sheet_form_header_screen.dart';
import 'screens/answer_sheets/answer_sheet_form_count_screen.dart';
import 'screens/answer_sheets/answer_sheet_form_question_screen.dart';
import 'screens/answer_sheets/answer_sheet_form_preview_screen.dart';

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

class BubbleSheetApp extends StatelessWidget {
  const BubbleSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
        debugShowCheckedModeBanner: false,
      );
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) {
            final loggedIn = Provider.of<AuthProvider>(context, listen: false).currentUser != null;
            if (loggedIn) {
              return '/classes';
            } else {
              return '/login';
            }
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/classes',
          builder: (context, state) => const MainLayout(child: ClassListScreen()),
        ),
        GoRoute(
          path: '/classes/new',
          builder: (context, state) => const MainLayout(child: ClassAddScreen()),
        ),
        GoRoute(
          path: '/classes/:id',
          builder: (context, state) => MainLayout(
            child: ClassEditScreen(classCode: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/classes/:id/students',
          builder: (context, state) => MainLayout(
            child: ClassEditStudentsScreen(classCode: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/students',
          builder: (context, state) => const MainLayout(child: StudentListScreen()),
        ),
        GoRoute(
          path: '/students/new',
          builder: (context, state) => const MainLayout(child: StudentFormScreen()),
        ),
        GoRoute(
          path: '/students/importStudent',
          builder: (context, state) => const MainLayout(child: StudentImportScreen()),
        ),
        GoRoute(
          path: '/students/:id',
          builder: (context, state) => MainLayout(
            child: StudentFormScreen(studentId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/user',
          builder: (context, state) => const MainLayout(child: UserScreen()),
        ),
        // Answer Sheet routes
        GoRoute(
          path: '/answer-sheets',
          builder: (context, state) => const MainLayout(child: AnswerSheetListScreen()),
        ),
        GoRoute(
          path: '/answer-sheets/create/name',
          builder: (context, state) => const MainLayout(child: AnswerSheetFormNameScreen()),
        ),
        GoRoute(
          path: '/answer-sheets/create/header',
          builder: (context, state) => const MainLayout(child: AnswerSheetFormHeaderScreen()),
        ),
        GoRoute(
          path: '/answer-sheets/create/count',
          builder: (context, state) => const MainLayout(child: AnswerSheetFormCountScreen()),
        ),
        GoRoute(
          path: '/answer-sheets/create/question',
          builder: (context, state) => const MainLayout(child: AnswerSheetFormQuestionScreen()),
        ),
        GoRoute(
          path: '/answer-sheets/create/preview',
          builder: (context, state) => const MainLayout(child: AnswerSheetFormPreviewScreen()),
        ),
        GoRoute(
          path: '/quizzes',
          builder: (context, state) => MainLayout(child: QuizzListScreen())
        ),
        GoRoute(
          path: '/quizzes/new',
          builder: (context, state) => MainLayout(child: QuizFormScreen()),
        ),
        GoRoute(
          path: '/quizzes/:quizId',
          builder: (context, state) => MainLayout(
            child: QuizDetailScreen(quizId: state.pathParameters['quizId']!),
          ),
        ),
        GoRoute(
          path: '/quizzes/:quizId/edit-answer-keys',
          builder: (context, state) => MainLayout(
            child: QuizEditAnswerKeyScreen(quizId: state.pathParameters['quizId']!),
          ),
        ),
        GoRoute(
          path: '/quizzes/:quizId/edit',
          builder: (context, state) {
            final quizId = state.pathParameters['quizId']!;
            final examProvider = Provider.of<ExamProvider>(context, listen: false);
            final quizList = examProvider.exams.where((e) => e.id == quizId);
            final quiz = quizList.isNotEmpty ? quizList.first : null;
            return MainLayout(
              child: QuizFormScreen(quiz: quiz),
            );
          },
        ),
      ],
      redirect: (context, state) {
        final loggedIn = authProvider.currentUser != null;
        final isAtLogin = state.uri.path == '/login';
        final isAtRegister = state.uri.path == '/register';

        if (!loggedIn && !isAtLogin && !isAtRegister) return '/login';
        if (loggedIn && (isAtLogin || isAtRegister)) return '/classes';
        return null;
      },
      refreshListenable: authProvider,
    );
    return MaterialApp.router(
      routerConfig: router,
      title: 'BubbleSheet',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
    );
  }
} 