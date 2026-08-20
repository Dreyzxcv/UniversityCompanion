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
    _NavTab(Icons.calculate_outlined, Icons.calculate_rounded, 'QPI'),
  ];

  void _switchTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider<TermController>(
      create: (_) => TermController(firestoreService),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onSwitchTab: _switchTab),
            const ScheduleScreen(),
            const TasksScreen(),
            const ReviewerListScreen(),
            const QpiScreen(),
          ],
        ),
        bottomNavigationBar: _NavBar(
          index: _index,
          tabs: _tabs,
          isDark: isDark,
          onTap: _switchTab,
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final List<_NavTab> tabs;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _NavBar({
    required this.index,
    required this.tabs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: isDark ? AppColorsDark.surface : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppColorsDark.cardBorder : AppColors.cardBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.35)
                    : AppColors.navyDark.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Padding inside the bar so pills don't touch the edges
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final selected = i == index;
                return selected
                    ? Flexible(
                        flex: 2,
                        child: _NavItem(
                          icon: tabs[i].icon,
                          selectedIcon: tabs[i].selectedIcon,
                          label: tabs[i].label,
                          selected: true,
                          isDark: isDark,
                          onTap: () => onTap(i),
                        ),
                      )
                    : Flexible(
                        flex: 1,
                        child: _NavItem(
                          icon: tabs[i].icon,
                          selectedIcon: tabs[i].selectedIcon,
                          label: tabs[i].label,
                          selected: false,
                          isDark: isDark,
                          onTap: () => onTap(i),
                        ),
                      );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? AppColorsDark.navyMid : AppColors.navyDark;
    final inactiveColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final activeBg = isDark ? AppColorsDark.pillLavender : AppColors.pillLavender;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: selected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: selected
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIcon, color: activeColor, size: 19),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: activeColor,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: inactiveColor, size: 21),
                ],
              ),
      ),
    );
  }
}