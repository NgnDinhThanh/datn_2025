import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import 'dart:async';

// User Menu Widget với hover behavior
class UserMenuWidget extends StatefulWidget {
  final String currentUser;

  const UserMenuWidget({super.key, required this.currentUser});

  @override
  State<UserMenuWidget> createState() => _UserMenuWidgetState();
}

class _UserMenuWidgetState extends State<UserMenuWidget> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  // Hàm hiển thị menu
  void _showMenu() {
    // Cancel timer nếu có
    _hideTimer?.cancel();
    _hideTimer = null;
    
    if (_overlayEntry != null) return; // Menu đã mở
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  // Hàm ẩn menu với delay
  void _hideMenu({Duration delay = const Duration(milliseconds: 150)}) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      if (mounted && _overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  // Hàm ẩn menu ngay lập tức
  void _hideMenuImmediately() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // Tạo OverlayEntry cho menu
  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: 180,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onEnter: (_) {
                // Cancel timer khi hover vào menu
                _hideTimer?.cancel();
                _hideTimer = null;
              },
              onExit: (_) {
                // Đóng menu khi hover ra khỏi menu
                _hideMenu();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MenuItem(
                      icon: Icons.person,
                      label: 'My Account',
                      onTap: () {
                        _hideMenuImmediately();
                        GoRouter.of(context).go('/user');
                      },
                    ),
                    const Divider(height: 1, color: Colors.grey),
                    _MenuItem(
                      icon: Icons.logout,
                      label: 'Log Out',
                      onTap: () async {
                        _hideMenuImmediately();
                        final authProvider = context.read<AuthProvider>();
                        await authProvider.logout();
                        if (mounted) {
                          GoRouter.of(context).go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideMenuImmediately();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _showMenu(),
        onExit: (_) {
          // Đóng menu khi hover ra khỏi button (với delay để user có thể di chuyển sang menu)
          _hideMenu();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current User: ',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              Text(
                widget.currentUser,
                style: TextStyle(
                  color: Colors.blueGrey[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget cho menu item
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.grey[300],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    "My Account",
  ];

  static const List<String> _tabRoutes = [
    "/quizzes",
    "/classes",
    "/students",
    "/answer-sheets",
    "/user",
  ];

  @override
  Widget build(BuildContext context) {
    // Provide context to ApiService for 401 handling (logout + navigate)
    ApiService.setContext(context);
    final currentUser = context.watch<AuthProvider>().currentUser ?? '';
    // Prefer provided currentPath, otherwise read from GoRouter (only valid under a GoRoute builder)
    String resolvedPath = currentPath ?? '';
    if (resolvedPath.isEmpty) {
      final state = GoRouter.maybeOf(
        context,
      )?.routerDelegate.currentConfiguration; // may be null if not under router
      resolvedPath = state?.uri.toString() ?? '/';
    }

    // Xác định tab đang active dựa vào URL
    int selectedIndex = _tabRoutes.indexWhere(
      (route) => resolvedPath.contains(route),
    );
    if (selectedIndex == -1) selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 80.0),
          child: Text("BubbleSheet"),
        ),
        titleSpacing: 0, // Disable default title spacing để control padding bằng Padding widget
        actions: [
          // User Menu với hover behavior
          UserMenuWidget(currentUser: currentUser),
        ],
        actionsPadding: const EdgeInsets.only(right: 80.0), // Padding cho actions (bên phải)
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
                      fontWeight: selectedIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selectedIndex == index
                          ? Colors.blue
                          : Colors.black87,
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
