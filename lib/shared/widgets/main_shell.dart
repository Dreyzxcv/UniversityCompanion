import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/term_controller.dart';
import '../../schedule/schedule_screen.dart';
import '../../qpi_calculator/qpi_screen.dart';
import 'home_screen.dart';

/// Bottom-nav shell. Only Home, Schedule, and QPI Calculator are wired up
/// for this MVP; Chat/Board are intentionally left out rather than stubbed
/// as disabled tabs, to keep the nav bar honest about what's built.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return ChangeNotifierProvider<TermController>(
      create: (_) => TermController(firestoreService),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            ScheduleScreen(),
            QpiScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'QPI Calc',
            ),
          ],
        ),
      ),
    );
  }
}
