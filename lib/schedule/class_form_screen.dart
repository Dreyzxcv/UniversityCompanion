import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../shared/models/class_session.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/color_palette.dart';

/// Returned by the form on save; the caller decides how to persist it.
class ClassFormResult {
  final ClassSession session;
  final bool isNew;
  ClassFormResult(this.session, this.isNew);
}

class ClassFormScreen extends StatefulWidget {
  final ClassSession? existing;
  final List<ClassSession> allClassesInTerm;

  const ClassFormScreen({
    super.key,
    this.existing,
    required this.allClassesInTerm,
  });

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectCodeCtrl;
  late TextEditingController _subjectNameCtrl;
  late TextEditingController _sectionCtrl;
  late TextEditingController _unitsCtrl;
  late TextEditingController _professorCtrl;
  late TextEditingController _roomCtrl;

  String _day = kWeekDays.first;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  String _color = kPastelPalette.first;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _subjectCodeCtrl = TextEditingController(text: e?.subjectCode ?? '');
    _subjectNameCtrl = TextEditingController(text: e?.subjectName ?? '');
    _sectionCtrl = TextEditingController(text: e?.section ?? '');
    _unitsCtrl = TextEditingController(text: e?.units.toString() ?? '3');
    _professorCtrl = TextEditingController(text: e?.professor ?? '');
    _roomCtrl = TextEditingController(text: e?.room ?? '');
    if (e != null) {
      _day = e.day;
      _startTime = _parseTime(e.startTime);
      _endTime = _parseTime(e.endTime);
      _color = e.color;
    }
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    if (endMin <= startMin) {
      _showError('End time must be after start time.');
      return;
    }

    final candidate = ClassSession(
      id: widget.existing?.id ?? const Uuid().v4(),
      subjectCode: _subjectCodeCtrl.text.trim(),
      subjectName: _subjectNameCtrl.text.trim(),
      section: _sectionCtrl.text.trim(),
      units: num.tryParse(_unitsCtrl.text.trim()) ?? 0,
      professor: _professorCtrl.text.trim(),
      day: _day,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      room: _roomCtrl.text.trim(),
      color: _color,
    );

    final conflicts = findConflicts(candidate, widget.allClassesInTerm);
    if (conflicts.isNotEmpty) {
      _confirmConflictAndSave(candidate, conflicts);
    } else {
      Navigator.pop(context, ClassFormResult(candidate, !_isEditing));
    }
  }

  Future<void> _confirmConflictAndSave(
    ClassSession candidate,
    List<ClassSession> conflicts,
  ) async {
    final names = conflicts.map((c) => '${c.subjectCode} (${c.startTime}-${c.endTime})').join(', ');
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Schedule Conflict'),
        content: Text(
          'This overlaps with $names on ${candidate.day}. Save it anyway?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) {
      Navigator.pop(context, ClassFormResult(candidate, !_isEditing));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(msg),
      ),
    );
  }

  @override
  void dispose() {
    _subjectCodeCtrl.dispose();
    _subjectNameCtrl.dispose();
    _sectionCtrl.dispose();
    _unitsCtrl.dispose();
    _professorCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Class' : 'Add Class')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                icon: Icons.menu_book_rounded,
                title: 'Subject Details',
                children: [
                  TextFormField(
                    controller: _subjectCodeCtrl,
                    decoration: const InputDecoration(labelText: 'Subject code'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _subjectNameCtrl,
                    decoration: const InputDecoration(labelText: 'Subject name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sectionCtrl,
                          decoration: const InputDecoration(labelText: 'Section'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _unitsCtrl,
                          decoration: const InputDecoration(labelText: 'Units'),
                          keyboardType: TextInputType.number,
                          validator: (v) => (num.tryParse(v ?? '') == null) ? 'Invalid' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _professorCtrl,
                    decoration: const InputDecoration(labelText: 'Professor'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _roomCtrl,
                    decoration: const InputDecoration(labelText: 'Room'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.schedule_rounded,
                title: 'Schedule',
                children: [
                  DropdownButtonFormField<String>(
                    value: _day,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: kWeekDays
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => _day = v!),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePickerTile(
                          label: 'Start',
                          time: _startTime.format(context),
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimePickerTile(
                          label: 'End',
                          time: _endTime.format(context),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.palette_rounded,
                title: 'Color',
                children: [
                  ColorPickerRow(
                    selected: _color,
                    onSelected: (c) => setState(() => _color = c),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save Changes' : 'Add Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded white card with a small icon-chip header, matching the visual
/// language used on the Home screen (`_SchoolCard`, `_UpcomingCard`).
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.pillLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.navyDark, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Time-picker button styled like the app's other outlined chips rather
/// than a bare OutlinedButton, so it reads as an input field.
class _TimePickerTile extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.pillLavender.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: AppColors.navyDark),
                const SizedBox(width: 6),
                Text(time, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}