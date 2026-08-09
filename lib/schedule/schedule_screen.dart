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
    final notifPrefs = context.read<NotificationPreferencesController>().prefs;
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
    // One session per selected day (e.g. MON/THU) — write each as its
    // own class doc and schedule its own reminder.
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

    // Editing always stays tied to the single doc being edited, so this
    // is exactly one session regardless of the day picked.
    final session = result.sessions.first;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.save_outlined, color: AppColors.navyDark),
              title: const Text('Save changes'),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.overdue),
              title: const Text('Delete class',
                  style: TextStyle(color: AppColors.overdue)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (action == null) {
      await context.read<FirestoreService>().updateClass(termId, session);
      if (!context.mounted) return;
      await _syncReminder(context, session);
      return;
    }
    if (action == 'save') {
      await context.read<FirestoreService>().updateClass(termId, session);
      if (!context.mounted) return;
      await _syncReminder(context, session);
    } else if (action == 'delete' && context.mounted) {
      await _confirmDelete(context, termId, existing.id);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String termId, String classId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete class?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<FirestoreService>().deleteClass(termId, classId);
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: _ScheduleHeader(),
            ),
            Expanded(
              child: termId == null
                  ? const Align(
                      alignment: Alignment.topCenter,
                      child: _NoTermCard(),
                    )
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
                          return _EmptyScheduleCard(
                            onAddClass: () =>
                                _openAddForm(context, termId, classes),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: context.cardBorderColor),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: WeeklyGrid(
                              classes: classes,
                              onTapClass: (session) => _openEditForm(
                                  context, termId, session, classes),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
                    onPressed: () => _openAddForm(context, termId, classes),
                    backgroundColor: AppColors.navyDark,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
    );
  }
}

/// Time format now lives in Settings (see SettingsScreen), so this header
/// is back to just the title + term selector — no clock icon shortcut.
class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Class Schedule',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.pillLavender,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const TermSelector(),
          ),
        ),
      ],
    );
  }
}

/// Matches HomeScreen's _NoTermHero: navy gradient card instead of a
/// plain gray empty-state icon.
class _NoTermCard extends StatelessWidget {
  const _NoTermCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.calendar_month_rounded, color: Colors.white, size: 40),
            SizedBox(height: 16),
            Text(
              'No term selected',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Create a term to start building your schedule.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty schedule state, restyled with a rounded lavender icon badge and
/// theme-consistent typography instead of the generic gray icon.
class _EmptyScheduleCard extends StatelessWidget {
  final VoidCallback onAddClass;
  const _EmptyScheduleCard({required this.onAddClass});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.pillLavender,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.event_busy_rounded,
                  size: 40, color: AppColors.navyDark),
            ),
            const SizedBox(height: 20),
            const Text(
              'No classes yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first class for this term.',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddClass,
              icon: const Icon(Icons.add),
              label: const Text('Add Class'),
            ),
          ],
        ),
      ),
    );
  }
}