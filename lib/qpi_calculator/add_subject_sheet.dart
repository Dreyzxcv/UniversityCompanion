import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../shared/models/grade_record.dart';
import '../shared/models/grade_scale.dart';
import '../shared/theme/app_theme.dart';

const List<int> kUnitOptions = [1, 2, 3, 4, 5, 6];

Future<GradeRecord?> showAddSubjectSheet(
  BuildContext context, {
  GradeRecord? existing,
}) {
  return showModalBottomSheet<GradeRecord>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
  late TextEditingController _customGradeCtrl;
  int _units = 3;

  // Either a quick-pick label from the standard scale, or null when the
  // person is using the custom numeric field instead (e.g. a school that
  // grades in increments the standard scale doesn't cover, like 1.8).
  String? _gradeLabel;
  bool _useCustomGrade = false;
  String? _customGradeError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.subjectName ?? '');
    _codeCtrl = TextEditingController(text: e?.subjectCode ?? '');
    _customGradeCtrl = TextEditingController();

    if (e != null) {
      _units = e.units.toInt();
      final scale = gradeScaleById(e.gradeScaleId);
      final match = scale.entries.where((x) => x.points == e.grade).toList();
      if (match.isNotEmpty) {
        _gradeLabel = match.first.label;
      } else {
        // Existing grade doesn't match a standard entry (e.g. 1.8) —
        // open straight into the custom field with that value prefilled.
        _useCustomGrade = true;
        _customGradeCtrl.text = e.grade.toStringAsFixed(2);
      }
    } else {
      _gradeLabel = defaultGradeScale.entries.first.label;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _customGradeCtrl.dispose();
    super.dispose();
  }

  double? _resolveGradePoints() {
    if (_useCustomGrade) {
      final parsed = double.tryParse(_customGradeCtrl.text.trim());
      if (parsed == null) return null;
      if (parsed < defaultGradeScale.bestPoints || parsed > defaultGradeScale.worstPoints) {
        return null;
      }
      return parsed;
    }
    return defaultGradeScale.pointsForLabel(_gradeLabel ?? '');
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final points = _resolveGradePoints();
    if (points == null) {
      setState(() => _customGradeError = 'Enter a value from 1.00 to 5.00');
      return;
    }

    final record = GradeRecord(
      id: widget.existing?.id ?? const Uuid().v4(),
      subjectCode: _codeCtrl.text.trim(),
      subjectName: _nameCtrl.text.trim(),
      units: _units,
      grade: points,
      gradeScaleId: defaultGradeScale.id,
    );
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
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
                        widget.existing == null ? Icons.add_rounded : Icons.edit_rounded,
                        color: AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.existing == null ? 'Add Subject' : 'Edit Subject',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                DropdownButtonFormField<int>(
                  value: _units,
                  decoration: const InputDecoration(labelText: 'Units'),
                  items: kUnitOptions
                      .map((u) => DropdownMenuItem(value: u, child: Text('$u')))
                      .toList(),
                  onChanged: (v) => setState(() => _units = v!),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Grade',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...defaultGradeScale.entries.map((e) {
                      final selected = !_useCustomGrade && _gradeLabel == e.label;
                      final tier = standingFor(e.points, defaultGradeScale).tier;
                      return ChoiceChip(
                        label: Text(e.label),
                        selected: selected,
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.forTier(tier),
                            shape: BoxShape.circle,
                          ),
                        ),
                        onSelected: (_) => setState(() {
                          _useCustomGrade = false;
                          _gradeLabel = e.label;
                        }),
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
                    ChoiceChip(
                      label: const Text('Custom'),
                      selected: _useCustomGrade,
                      onSelected: (_) => setState(() {
                        _useCustomGrade = true;
                        _customGradeError = null;
                      }),
                      selectedColor: AppColors.navyDark,
                      labelStyle: TextStyle(
                        color: _useCustomGrade ? Colors.white : AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: AppColors.pillLavender.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide.none,
                      ),
                    ),
                  ],
                ),
                if (_useCustomGrade) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customGradeCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Exact grade',
                      hintText: 'e.g. 1.8',
                      errorText: _customGradeError,
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                    ),
                    onChanged: (_) => setState(() => _customGradeError = null),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'For schools that grade in finer increments than the standard scale.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  '1.00 is the highest grade, 5.00 is failing.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _save,
                  child: Text(widget.existing == null ? 'Add Subject' : 'Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}