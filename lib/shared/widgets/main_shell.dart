import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/term_controller.dart';
import '../theme/app_theme.dart';
import '../../schedule/schedule_screen.dart';
import '../../qpi_calculator/qpi_screen.dart';
import 'home_screen.dart';
import '../../tasks/tasks_screen.dart';
import '../../reviewer/reviewer_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _NavTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavTab(this.icon, this.selectedIcon, this.label);
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    _NavTab(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavTab(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Schedule'),
    _NavTab(Icons.assignment_outlined, Icons.assignment_rounded, 'Tasks'),
    _NavTab(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Review'),
    _NavTab(Icons.calculate_outlined, Icons.calculate_rounded, 'QPI Calc'),
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return ChangeNotifierProvider<TermController>(
      create: (_) => TermController(firestoreService),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            ScheduleScreen(),
            TasksScreen(),
            ReviewerListScreen(),
            QpiScreen(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final selected = i == _index;
                  return _NavItem(
                    icon: selected ? tab.selectedIcon : tab.icon,
                    label: tab.label,
                    selected: selected,
                    onTap: () => setState(() => _index = i),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navyDark : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.textMuted, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}