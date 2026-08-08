import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../shared/models/task_item.dart';
import '../shared/models/class_session.dart';
import '../shared/theme/app_theme.dart';

/// Result of the add/edit task sheet. Either the person saved a task
/// (populated [task]) or, when editing, chose to delete it ([isDelete]).
/// Dismissing the sheet without either action returns null from
/// [showAddTaskSheet] itself, so callers only need to check this class
/// when a result is actually returned.
class TaskSheetResult {
  final TaskItem? task;
  final bool isDelete;

  const TaskSheetResult.save(TaskItem this.task) : isDelete = false;
  const TaskSheetResult.delete()
      : task = null,
        isDelete = true;
}

Future<TaskSheetResult?> showAddTaskSheet(
  BuildContext context, {
  required List<ClassSession> classes,
  TaskItem? existing,
}) {
  return showModalBottomSheet<TaskSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddTaskSheet(classes: classes, existing: existing),
  );
}

class _AddTaskSheet extends StatefulWidget {
  final List<ClassSession> classes;
  final TaskItem? existing;
  const _AddTaskSheet({required this.classes, this.existing});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _notesCtrl;
  TaskType _type = TaskType.assignment;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  String? _classId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      _type = e.type;
      _dueDate = e.dueDate;
      _classId = e.classId;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final task = TaskItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      type: _type,
      dueDate: _dueDate,
      classId: _classId,
      notes: _notesCtrl.text.trim(),
      isCompleted: widget.existing?.isCompleted ?? false,
    );
    Navigator.pop(context, TaskSheetResult.save(task));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete task?'),
        content: Text(
          'This will permanently delete "${_titleCtrl.text.trim().isEmpty ? 'this task' : _titleCtrl.text.trim()}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, const TaskSheetResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.pillLavender,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_rounded : Icons.add_rounded,
                        color: AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Task' : 'Add Task',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
                      ),
                    ),
                    if (isEditing)
                      IconButton(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.overdue,
                        tooltip: 'Delete task',
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const Text('Type',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TaskType.values.map((t) {
                    final selected = _type == t;
                    return ChoiceChip(
                      label: Text(t.label),
                      avatar: Icon(t.icon, size: 16, color: selected ? Colors.white : AppColors.navyDark),
                      selected: selected,
                      onSelected: (_) => setState(() => _type = t),
                      selectedColor: AppColors.navyDark,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: AppColors.pillLavender.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Due date',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.pillLavender.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.navyDark),
                        const SizedBox(width: 10),
                        Text(
                          '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.classes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Link to class (optional)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: _classId == null,
                        onSelected: (_) => setState(() => _classId = null),
                        selectedColor: AppColors.navyDark,
                        labelStyle: TextStyle(
                          color: _classId == null ? Colors.white : AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: AppColors.pillLavender.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                      ),
                      ...widget.classes.map((c) {
                        final selected = _classId == c.id;
                        return ChoiceChip(
                          label: Text(c.subjectCode),
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: c.colorValue, shape: BoxShape.circle),
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => _classId = c.id),
                          selectedColor: AppColors.navyDark,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: AppColors.pillLavender.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                const Text(
                  "You'll get a reminder the evening before it's due.",
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Save Changes' : 'Add Task'),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete Task'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.overdue,
                      side: const BorderSide(color: AppColors.overdue, width: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}