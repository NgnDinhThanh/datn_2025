import 'package:bubblesheet_frontend/widgets/app_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import 'dart:async';

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

  // show menu
  void _showMenu() {
    _hideTimer?.cancel();
    _hideTimer = null;

    if (_overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  // hide menu with delay
  void _hideMenu({Duration delay = const Duration(milliseconds: 150)}) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      if (mounted && _overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  // hide menu immediately
  void _hideMenuImmediately() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

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
                _hideTimer?.cancel();
                _hideTimer = null;
              },
              onExit: (_) {
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
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
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

// Widget for menu item
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
            Icon(icon, color: Colors.grey[300], size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// Logo Widget
class AppLogoWidget extends StatelessWidget {
  const AppLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        hoverColor: Colors.white,
        onTap: () {
          GoRouter.of(context).go('/user');
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Image.asset(
            'images/logo.png',
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'BubbleSheet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  final Widget child;
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
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provide context to ApiService for 401 handling (logout + navigate)
    ApiService.setContext(context);
    final currentUser = context.watch<AuthProvider>().currentUser ?? '';
    String resolvedPath = widget.currentPath ?? '';
    if (resolvedPath.isEmpty) {
      final state = GoRouter.maybeOf(
        context,
      )?.routerDelegate.currentConfiguration; // may be null if not under router
      resolvedPath = state?.uri.toString() ?? '/';
    }

    int selectedIndex = MainLayout._tabRoutes.indexWhere(
      (route) => resolvedPath.contains(route),
    );
    if (selectedIndex == -1) selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AppLogoWidget(),
                UserMenuWidget(currentUser: currentUser),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          Container(
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(MainLayout._tabTitles.length, (index) {
                return TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () {
                    final router = GoRouter.maybeOf(context);
                    if (router == null) return;
                    if (index == 0) {
                      router.go('/quizzes');
                    } else if (selectedIndex != index) {
                      router.go(MainLayout._tabRoutes[index]);
                    }
                  },
                  child: Text(
                    MainLayout._tabTitles[index],
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [widget.child, const AppFooter()],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
