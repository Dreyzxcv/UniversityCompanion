import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../shared/models/class_session.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subjectCodeCtrl,
                decoration: const InputDecoration(labelText: 'Subject code'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectNameCtrl,
                decoration: const InputDecoration(labelText: 'Subject name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _professorCtrl,
                decoration: const InputDecoration(labelText: 'Professor'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomCtrl,
                decoration: const InputDecoration(labelText: 'Room'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: kWeekDays
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _day = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(isStart: true),
                      child: Text('Start: ${_startTime.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(isStart: false),
                      child: Text('End: ${_endTime.format(context)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              ColorPickerRow(
                selected: _color,
                onSelected: (c) => setState(() => _color = c),
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
