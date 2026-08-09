import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/task_item.dart';
import '../shared/models/class_session.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/term_controller.dart';
import '../shared/services/notification_service.dart';
import '../shared/services/notification_preferences.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/term_selector.dart';
import 'add_task_sheet.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  Future<void> _syncReminder(BuildContext context, TaskItem task) async {
    if (task.isCompleted) {
      await NotificationService.instance.cancelTaskReminder(task.id);
      return;
    }
    final notifPrefs = context.read<NotificationPreferencesController>().prefs;
    if (notifPrefs.enabled) {
      await NotificationService.instance.scheduleTaskReminder(
        task,
        daysBefore: notifPrefs.taskReminderDaysBefore,
      );
    } else {
      await NotificationService.instance.cancelTaskReminder(task.id);
    }
  }

  Future<void> _addTask(BuildContext context, String termId, List<ClassSession> classes) async {
    final result = await showAddTaskSheet(context, classes: classes);
    if (result == null || result.task == null || !context.mounted) return;
    final service = context.read<FirestoreService>();
    await service.addTask(termId, result.task!);
    if (!context.mounted) return;
    await _syncReminder(context, result.task!);
  }

  Future<void> _editTask(
    BuildContext context,
    String termId,
    TaskItem existing,
    List<ClassSession> classes,
  ) async {
    final result = await showAddTaskSheet(context, classes: classes, existing: existing);
    if (result == null || !context.mounted) return;

    final service = context.read<FirestoreService>();
    if (result.isDelete) {
      await service.deleteTask(termId, existing.id);
      await NotificationService.instance.cancelTaskReminder(existing.id);
      return;
    }

    final task = result.task;
    if (task == null) return;
    await service.updateTask(termId, task);
    if (!context.mounted) return;
    await _syncReminder(context, task);
  }

  Future<void> _toggleComplete(BuildContext context, String termId, TaskItem task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    final service = context.read<FirestoreService>();
    await service.updateTask(termId, updated);
    if (!context.mounted) return;
    await _syncReminder(context, updated);
  }

  Future<void> _deleteTask(BuildContext context, String termId, String taskId) async {
    final service = context.read<FirestoreService>();
    await service.deleteTask(termId, taskId);
    await NotificationService.instance.cancelTaskReminder(taskId);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.pillLavender,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const TermSelector(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: termId == null
                  ? const Align(alignment: Alignment.topCenter, child: _NoTermCard())
                  : StreamBuilder<List<ClassSession>>(
                      stream: firestoreService.watchClasses(termId),
                      builder: (context, classSnap) {
                        final classes = classSnap.data ?? [];
                        return StreamBuilder<List<TaskItem>>(
                          stream: firestoreService.watchTasks(termId),
                          builder: (context, taskSnap) {
                            if (taskSnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final tasks = taskSnap.data ?? [];
                            if (tasks.isEmpty) {
                              return EmptyState(
                                icon: Icons.assignment_turned_in_outlined,
                                title: 'No tasks yet',
                                message:
                                    'Add exams, assignments, and projects to keep track of deadlines.',
                                ctaLabel: 'Add Task',
                                onCta: () => _addTask(context, termId, classes),
                              );
                            }
                            return _TaskListView(
                              tasks: tasks,
                              classes: classes,
                              onToggle: (t) => _toggleComplete(context, termId, t),
                              onTap: (t) => _editTask(context, termId, t, classes),
                              onDelete: (t) => _deleteTask(context, termId, t.id),
                            );
                          },
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
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 90),
                  child: FloatingActionButton(
                    onPressed: () => _addTask(context, termId, classes),
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
            Icon(Icons.assignment_outlined, color: Colors.white, size: 40),
            SizedBox(height: 16),
            Text('No term selected',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Create a term to start tracking tasks.',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _TaskListView extends StatelessWidget {
  final List<TaskItem> tasks;
  final List<ClassSession> classes;
  final ValueChanged<TaskItem> onToggle;
  final ValueChanged<TaskItem> onTap;
  final ValueChanged<TaskItem> onDelete;

  const _TaskListView({
    required this.tasks,
    required this.classes,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  ClassSession? _classFor(String? classId) {
    if (classId == null) return null;
    for (final c in classes) {
      if (c.id == classId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pending = tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final completed = tasks.where((t) => t.isCompleted).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    final overdue = pending.where((t) => t.isOverdue).toList();
    final today = pending.where((t) => !t.isOverdue && t.isDueToday).toList();
    final upcoming = pending.where((t) => !t.isOverdue && !t.isDueToday).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        if (overdue.isNotEmpty)
          _Section(
            title: 'Overdue',
            color: AppColors.overdue,
            children: [
              for (final t in overdue)
                _TaskTile(
                  task: t,
                  linkedClass: _classFor(t.classId),
                  onToggle: () => onToggle(t),
                  onTap: () => onTap(t),
                  onDelete: () => onDelete(t),
                ),
            ],
          ),
        if (today.isNotEmpty)
          _Section(
            title: 'Today',
            color: AppColors.navyDark,
            children: [
              for (final t in today)
                _TaskTile(
                  task: t,
                  linkedClass: _classFor(t.classId),
                  onToggle: () => onToggle(t),
                  onTap: () => onTap(t),
                  onDelete: () => onDelete(t),
                ),
            ],
          ),
        if (upcoming.isNotEmpty)
          _Section(
            title: 'Upcoming',
            color: AppColors.textMuted,
            children: [
              for (final t in upcoming)
                _TaskTile(
                  task: t,
                  linkedClass: _classFor(t.classId),
                  onToggle: () => onToggle(t),
                  onTap: () => onTap(t),
                  onDelete: () => onDelete(t),
                ),
            ],
          ),
        if (completed.isNotEmpty)
          _Section(
            title: 'Completed (${completed.length})',
            color: AppColors.excellent,
            initiallyCollapsed: true,
            children: [
              for (final t in completed)
                _TaskTile(
                  task: t,
                  linkedClass: _classFor(t.classId),
                  onToggle: () => onToggle(t),
                  onTap: () => onTap(t),
                  onDelete: () => onDelete(t),
                ),
            ],
          ),
      ],
    );
  }
}

class _Section extends StatefulWidget {
  final String title;
  final Color color;
  final List<Widget> children;
  final bool initiallyCollapsed;

  const _Section({
    required this.title,
    required this.color,
    required this.children,
    this.initiallyCollapsed = false,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _collapsed = widget.initiallyCollapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _collapsed = !_collapsed),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: widget.color,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _collapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (!_collapsed) ...widget.children,
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskItem task;
  final ClassSession? linkedClass;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.linkedClass,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  String _dueLabel() {
    final now = DateTime.now();
    final due = task.dueDate;
    final diff = DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final dateStr = '${due.month}/${due.day}/${due.year}';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 0) return 'Was due $dateStr';
    return 'Due $dateStr';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = linkedClass?.colorValue ?? AppColors.pillLavender;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.overdue,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 5,
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
                shape: const CircleBorder(),
                activeColor: AppColors.excellent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(task.type.icon, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            task.type.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (linkedClass != null) ...[
                            const Text(' · ',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            Text(
                              linkedClass!.subjectCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? AppColors.textMuted : AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dueLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isOverdue ? AppColors.overdue : AppColors.textMuted,
                          fontWeight: task.isOverdue ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}