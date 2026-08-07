import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/grade_record.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/term_controller.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/term_selector.dart';
import 'add_subject_sheet.dart';
import 'grade_scale_section.dart';
import 'qpi_trend_section.dart';
import '../shared/theme/app_theme.dart';

class QpiScreen extends StatefulWidget {
  const QpiScreen({super.key});

  @override
  State<QpiScreen> createState() => _QpiScreenState();
}

class _QpiScreenState extends State<QpiScreen> {
  final _prevQpiCtrl = TextEditingController();
  final _prevUnitsCtrl = TextEditingController();
  bool _showPreviousRecord = false;

  @override
  void dispose() {
    _prevQpiCtrl.dispose();
    _prevUnitsCtrl.dispose();
    super.dispose();
  }

  double get _prevQpi => double.tryParse(_prevQpiCtrl.text.trim()) ?? 0.0;
  num get _prevUnits => num.tryParse(_prevUnitsCtrl.text.trim()) ?? 0;

  Future<void> _addSubject(BuildContext context, String termId) async {
    final record = await showAddSubjectSheet(context);
    if (record != null && context.mounted) {
      await context.read<FirestoreService>().addGrade(termId, record);
    }
  }

  Future<void> _editSubject(BuildContext context, String termId, GradeRecord existing) async {
    final record = await showAddSubjectSheet(context, existing: existing);
    if (record != null && context.mounted) {
      await context.read<FirestoreService>().updateGrade(termId, record);
    }
  }

  Future<void> _removeSubject(BuildContext context, String termId, String gradeId) async {
    await context.read<FirestoreService>().deleteGrade(termId, gradeId);
  }

  Future<void> _saveSemesterResult(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semester result saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final termController = context.watch<TermController>();
    final firestoreService = context.read<FirestoreService>();
    final termId = termController.selectedTermId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QPI Calculator'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: const TermSelector()),
          ),
        ],
      ),
      body: termId == null
          ? const EmptyState(
              icon: Icons.calculate_outlined,
              title: 'No term selected',
              message: 'Create a term first to start tracking your QPI.',
            )
          : StreamBuilder<List<GradeRecord>>(
              stream: firestoreService.watchGrades(termId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = snapshot.data ?? [];
                final semesterQpi = computeSemesterQpi(records);
                final semesterUnits = records.fold<num>(0, (sum, r) => sum + r.units);
                final cumulativeQpi = computeCumulativeQpi(
                  previousQpi: _prevQpi,
                  previousUnits: _prevUnits,
                  semesterQpi: semesterQpi,
                  semesterUnits: semesterUnits,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _QpiSummaryCard(
                            label: 'Semester QPI',
                            value: semesterQpi,
                            color: AppColors.pillLavender,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QpiSummaryCard(
                            label: 'Cumulative QPI',
                            value: cumulativeQpi,
                            color: AppColors.mint
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('This Semester', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No subjects added yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      ...records.map(
                        (r) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(r.subjectName),
                            subtitle: Text('${r.units} units · Grade point ${r.grade.toStringAsFixed(2)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editSubject(context, termId, r),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeSubject(context, termId, r.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _addSubject(context, termId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Subject'),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        leading: const Icon(Icons.history_rounded),
                        title: const Text('Previous Record'),
                        initiallyExpanded: _showPreviousRecord,
                        onExpansionChanged: (v) => setState(() => _showPreviousRecord = v),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _prevQpiCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Previous QPI'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _prevUnitsCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Previous Units'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: records.isEmpty ? null : () => _saveSemesterResult(context),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Calculate & Save'),
                    ),
                    const SizedBox(height: 20),
                    const GradeScaleSection(),
                    const SizedBox(height: 12),
                    QpiTrendSection(service: firestoreService),
                  ],
                );
              },
            ),
    );
  }
}

class _QpiSummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _QpiSummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
