import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../shared/models/grade_record.dart';
import '../shared/models/grade_scale.dart';

const List<int> kUnitOptions = [1, 2, 3, 4, 5, 6];

Future<GradeRecord?> showAddSubjectSheet(
  BuildContext context, {
  GradeRecord? existing,
}) {
  return showModalBottomSheet<GradeRecord>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddSubjectSheet(existing: existing),
  );
}

class _AddSubjectSheet extends StatefulWidget {
  final GradeRecord? existing;
  const _AddSubjectSheet({this.existing});

  @override
  State<_AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends State<_AddSubjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  int _units = 3;
  String _gradeLabel = ateneoScale.entries.first.label;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.subjectName ?? '');
    _codeCtrl = TextEditingController(text: e?.subjectCode ?? '');
    if (e != null) {
      _units = e.units.toInt();
      final match = ateneoScale.entries.where((x) => x.points == e.grade).toList();
      if (match.isNotEmpty) _gradeLabel = match.first.label;
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final points = ateneoScale.pointsForLabel(_gradeLabel) ?? 0.0;
    final record = GradeRecord(
      id: widget.existing?.id ?? const Uuid().v4(),
      subjectCode: _codeCtrl.text.trim(),
      subjectName: _nameCtrl.text.trim(),
      units: _units,
      grade: points,
      gradeScaleId: ateneoScale.id,
    );
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add Subject' : 'Edit Subject',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Subject name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Subject code (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _units,
                    decoration: const InputDecoration(labelText: 'Units'),
                    items: kUnitOptions
                        .map((u) => DropdownMenuItem(value: u, child: Text('$u')))
                        .toList(),
                    onChanged: (v) => setState(() => _units = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gradeLabel,
                    decoration: const InputDecoration(labelText: 'Grade'),
                    items: ateneoScale.entries
                        .map((e) => DropdownMenuItem(
                              value: e.label,
                              child: Text('${e.label} (${e.points})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _gradeLabel = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(widget.existing == null ? 'Add Subject' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
