import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/class_session.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/term_controller.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/term_selector.dart';
import '../shared/services/notification_service.dart';
import '../shared/services/notification_preferences.dart';
import 'class_form_screen.dart';
import 'weekly_grid.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  Future<void> _syncReminder(BuildContext context, ClassSession session) async {
    final notifPrefs =
        context.read<NotificationPreferencesController>().prefs;
    if (notifPrefs.enabled) {
      await NotificationService.instance.scheduleClassReminder(
        session,
        minutesBefore: notifPrefs.classReminderMinutesBefore,
      );
    } else {
      await NotificationService.instance.cancelClassReminder(session.id);
    }
  }

  Future<void> _openAddForm(
    BuildContext context,
    String termId,
    List<ClassSession> currentClasses,
  ) async {
    final result = await Navigator.push<ClassFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassFormScreen(allClassesInTerm: currentClasses),
      ),
    );
    if (result == null || !context.mounted) return;

    final service = context.read<FirestoreService>();
    await NotificationService.instance.requestPermission();
    for (final session in result.sessions) {
      await service.addClass(termId, session);
      if (!context.mounted) return;
      await _syncReminder(context, session);
    }
  }

  Future<void> _openEditForm(
    BuildContext context,
    String termId,
    ClassSession existing,
    List<ClassSession> currentClasses,
  ) async {
    final result = await Navigator.push<ClassFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassFormScreen(
          existing: existing,
          allClassesInTerm: currentClasses,
        ),
      ),
    );
    if (result == null || !context.mounted) return;

    final session = result.sessions.first;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ClassActionSheet(session: existing),
    );

    if (!context.mounted) return;

    if (action == null || action == 'save') {
      await context.read<FirestoreService>().updateClass(termId, session);
      if (!context.mounted) return;
      await _syncReminder(context, session);
    } else if (action == 'delete') {
      await _confirmDelete(context, termId, existing.id);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String termId, String classId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete class?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.overdue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context
          .read<FirestoreService>()
          .deleteClass(termId, classId);
      await NotificationService.instance.cancelClassReminder(classId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final termController = context.watch<TermController>();
    final firestoreService = context.read<FirestoreService>();
    final termId = termController.selectedTermId;

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────
            _ScheduleHeader(termId: termId),

            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: termId == null
                  ? const _NoTermCard()
                  : StreamBuilder<List<ClassSession>>(
                      stream: firestoreService.watchClasses(termId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final classes = snapshot.data ?? [];

                        if (classes.isEmpty) {
                          return _EmptySchedule(
                            onAdd: () =>
                                _openAddForm(context, termId, classes),
                          );
                        }

                        return _GridContainer(
                          classes: classes,
                          onTapClass: (s) =>
                              _openEditForm(context, termId, s, classes),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────
      floatingActionButton: termId == null
          ? null
          : StreamBuilder<List<ClassSession>>(
              stream: firestoreService.watchClasses(termId),
              builder: (context, snap) {
                final classes = snap.data ?? [];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 90,
                  ),
                  child: FloatingActionButton(
                    onPressed: () =>
                        _openAddForm(context, termId, classes),
                    backgroundColor: AppColors.navyDark,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleHeader extends StatelessWidget {
  final String? termId;
  const _ScheduleHeader({required this.termId});

  String _todayLabel() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Schedule',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _todayLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.pillBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const TermSelector(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid container — the white card wrapping WeeklyGrid
// ─────────────────────────────────────────────────────────────────────────────

class _GridContainer extends StatelessWidget {
  final List<ClassSession> classes;
  final void Function(ClassSession) onTapClass;

  const _GridContainer({
    required this.classes,
    required this.onTapClass,
  });

  @override
  Widget build(BuildContext context) {
    // Stats for the summary chips
    const dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayCode = dayCodes[DateTime.now().weekday - 1];
    final todayClasses =
        classes.where((c) => c.day == todayCode).length;
    final uniqueDays =
        classes.map((c) => c.day).toSet().length;

    return Column(
      children: [
        // Summary strip
        _SummaryStrip(
          todayCount: todayClasses,
          totalDays: uniqueDays,
          totalClasses: classes.length,
        ),

        // Grid card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: context.cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navyDark.withOpacity(
                        context.isDark ? 0.3 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: WeeklyGrid(
                  classes: classes,
                  onTapClass: onTapClass,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary strip — 3 quick-stat chips below the header
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final int todayCount;
  final int totalDays;
  final int totalClasses;

  const _SummaryStrip({
    required this.todayCount,
    required this.totalDays,
    required this.totalClasses,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.today_rounded,
            label: '$todayCount today',
            color: AppColors.navyDark,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.calendar_view_week_rounded,
            label: '$totalDays day${totalDays == 1 ? '' : 's'}',
            color: AppColors.navyMid,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.menu_book_outlined,
            label: '$totalClasses class${totalClasses == 1 ? '' : 'es'}',
            color: AppColors.excellent,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(context.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Class action bottom sheet (save / delete)
// ─────────────────────────────────────────────────────────────────────────────

class _ClassActionSheet extends StatelessWidget {
  final ClassSession session;
  const _ClassActionSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Class identity pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: session.colorValue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        session.subjectCode.length > 3
                            ? session.subjectCode.substring(0, 3)
                            : session.subjectCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: session.colorValue.computeLuminance() > 0.45
                              ? AppColors.textDark
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.subjectCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (session.subjectName.isNotEmpty)
                          Text(
                            session.subjectName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.cardBorder),

            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.pillLavender,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: AppColors.navyDark, size: 18),
              ),
              title: const Text(
                'Save changes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.overdue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline,
                    color: AppColors.overdue, size: 18),
              ),
              title: const Text(
                'Delete class',
                style: TextStyle(
                    color: AppColors.overdue,
                    fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySchedule extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySchedule({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.pillLavender,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 44,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No classes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your subjects to see your week at a glance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Class'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No term state
// ─────────────────────────────────────────────────────────────────────────────

class _NoTermCard extends StatelessWidget {
  const _NoTermCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 20),
            const Text(
              'No term selected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a term to start building your weekly schedule.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}