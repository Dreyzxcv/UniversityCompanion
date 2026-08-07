import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/class_session.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/term_controller.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/term_selector.dart';
import 'class_form_screen.dart';
import 'weekly_grid.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

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
    if (result != null && context.mounted) {
      await context.read<FirestoreService>().addClass(termId, result.session);
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

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('Save changes'),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete class', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    // Fallback: if the form already produced a result, just save it
    // directly rather than forcing a second confirmation for the common case.
    if (action == null) {
      await context.read<FirestoreService>().updateClass(termId, result.session);
      return;
    }
    if (action == 'save') {
      await context.read<FirestoreService>().updateClass(termId, result.session);
    } else if (action == 'delete' && context.mounted) {
      await _confirmDelete(context, termId, existing.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String termId, String classId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<FirestoreService>().deleteClass(termId, classId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final termController = context.watch<TermController>();
    final firestoreService = context.read<FirestoreService>();
    final termId = termController.selectedTermId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Schedule'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: const TermSelector()),
          ),
        ],
      ),
      floatingActionButton: termId == null
          ? null
          : StreamBuilder<List<ClassSession>>(
              stream: firestoreService.watchClasses(termId),
              builder: (context, snap) {
                final classes = snap.data ?? [];
                return FloatingActionButton(
                  onPressed: () => _openAddForm(context, termId, classes),
                  child: const Icon(Icons.add),
                );
              },
            ),
      body: termId == null
          ? EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No term selected',
              message: 'Create a term to start building your schedule.',
              ctaLabel: 'New Term',
              onCta: () {}, // TermSelector's + button handles creation
            )
          : StreamBuilder<List<ClassSession>>(
              stream: firestoreService.watchClasses(termId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final classes = snapshot.data ?? [];
                if (classes.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No classes yet',
                    message: 'Tap the + button to add your first class for this term.',
                    ctaLabel: 'Add Class',
                    onCta: () => _openAddForm(context, termId, classes),
                  );
                }
                return WeeklyGrid(
                  classes: classes,
                  onTapClass: (session) => _openEditForm(context, termId, session, classes),
                );
              },
            ),
    );
  }
}
