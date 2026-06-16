import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'admin_home_tab.dart';
import 'admin_analytics_tab.dart';
import 'admin_map_screen.dart';
import 'admin_profile_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  List<Widget> get _tabs => const [
        AdminHomeTab(),
        AdminAnalyticsTab(),
        SizedBox.shrink(),
        AdminMapScreen(),
        AdminProfileTab(),
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
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i != 2) setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AdminBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analytics'),
      _NavItem(icon: Icons.add, activeIcon: Icons.add, label: ''),
      _NavItem(icon: Icons.location_on_outlined, activeIcon: Icons.location_on_rounded, label: 'Map'),
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
