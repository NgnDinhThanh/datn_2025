import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'quizz_screen.dart';
import 'classes_screen.dart';
import 'students_screen.dart';
import 'admin_screen.dart';
import 'my_account_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  List<Widget> _buildScreens(bool isAdmin) => [
    const QuizzesScreen(),
    const ClassesScreen(),
    const StudentsScreen(),
    if (isAdmin) const AdminScreen(),
    const MyAccountScreen(),
  ];

  List<String> _tabTitles(bool isAdmin) => [
    'Quizzes',
    'Classes',
    'Students',
    if (isAdmin) 'Admin',
    'My Account',
  ];

  List<IconData> _tabIcons(bool isAdmin) => [
    Icons.check_box,
    Icons.group,
    Icons.person,
    if (isAdmin) Icons.admin_panel_settings,
    Icons.account_circle,
  ];

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final screens = _buildScreens(isAdmin);
    final tabTitles = _tabTitles(isAdmin);
    final tabIcons = _tabIcons(isAdmin);
    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabTitles.length, (index) {
              return _buildNavItem(index, tabTitles, tabIcons);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    List<String> tabTitles,
    List<IconData> tabIcons,
  ) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFF2E7D32) : Colors.grey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tabIcons[index], color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              tabTitles[index],
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
