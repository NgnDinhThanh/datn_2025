import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  // When not using GoRouter (e.g., direct MaterialApp.home), provide the current path
  // so we don't rely on GoRouterState.of(context).
  final String? currentPath;
  const MainLayout({super.key, required this.child, this.currentPath});

  static const List<String> _tabTitles = [
    "Quizzes",
    "Classes",
    "Students",
    "Answer Sheets",
    "My Account"
  ];

  static const List<String> _tabRoutes = [
    "/quizzes",
    "/classes",
    "/students",
    "/answer-sheets",
    "/user"
  ];

  @override
  Widget build(BuildContext context) {
    // Provide context to ApiService for 401 handling (logout + navigate)
    ApiService.setContext(context);
    final currentUser = context.watch<AuthProvider>().currentUser ?? '';
    // Prefer provided currentPath, otherwise read from GoRouter (only valid under a GoRoute builder)
    String resolvedPath = currentPath ?? '';
    if (resolvedPath.isEmpty) {
      final state = GoRouter.maybeOf(context)?.routerDelegate.currentConfiguration; // may be null if not under router
      resolvedPath = state?.uri.toString() ?? '/';
    }

    // Xác định tab đang active dựa vào URL
    int selectedIndex = _tabRoutes.indexWhere((route) => resolvedPath.contains(route));
    if (selectedIndex == -1) selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("BubbleSheet"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Current User: $currentUser',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          Container(
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tabTitles.length, (index) {
                return TextButton(
                  onPressed: () {
                    final router = GoRouter.maybeOf(context);
                    if (router == null) return; // not under router; do nothing
                    if (index == 0) {
                      router.go('/quizzes');
                    } else if (selectedIndex != index) {
                      router.go(_tabRoutes[index]);
                    }
                  },
                  child: Text(
                    _tabTitles[index],
                    style: TextStyle(
                      fontWeight: selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                      color: selectedIndex == index ? Colors.blue : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}