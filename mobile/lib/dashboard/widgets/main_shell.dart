import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/dashboard/home_tab.dart';
import '../../screens/dashboard/analytics_tab.dart';
import '../../screens/dashboard/level_tab.dart';
import '../../screens/dashboard/stations_tab.dart';
import '../../screens/dashboard/profile_tab.dart';
import '../../theme/app_theme.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) => setState(() => _currentIndex = index);

  List<Widget> get _tabs => const [
    HomeTab(),
    AnalyticsTab(),
    SizedBox.shrink(),
    LevelTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex,
        children: _tabs,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StationsTab()),
        ),
        backgroundColor: AppTheme.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.sensors, color: Colors.white, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i != 2) setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analytics'),
      _NavItem(icon: Icons.add, activeIcon: Icons.add, label: ''),
      _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'level'),
      _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            if (i == 2) return const SizedBox(width: 56);
            final active = currentIndex == i;
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? items[i].activeIcon : items[i].icon,
                      color: active ? AppTheme.primary : Colors.grey.shade400,
                      size: 24,
                    ),
                    if (items[i].label.isNotEmpty)
                      Text(
                        items[i].label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: active ? AppTheme.primary : Colors.grey.shade400,
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
