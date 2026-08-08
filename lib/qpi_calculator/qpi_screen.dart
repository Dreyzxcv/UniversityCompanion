import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/grade_record.dart';
import '../shared/models/grade_scale.dart';
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
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Text('Semester result saved.'),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.pillLavender,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: AppColors.navyDark),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'About QPI Calculator',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _InfoRow(
                icon: Icons.calculate_outlined,
                text: 'QPI (Quality Point Index) measures your academic standing. '
                    'Each subject\'s grade is weighted by its units, then averaged '
                    'across the semester.',
              ),
              const SizedBox(height: 14),
              const _InfoRow(
                icon: Icons.swap_vert_rounded,
                text: 'On the Philippine scale, 1.00 is the highest possible grade '
                    'and 5.00 means failing — so a lower QPI is actually better.',
              ),
              const SizedBox(height: 14),
              const _InfoRow(
                icon: Icons.stacked_line_chart_rounded,
                text: 'Semester QPI covers only the current term. Cumulative QPI '
                    'combines it with your previous record (enter that under '
                    '"Previous Record") to track your standing overall.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final termController = context.watch<TermController>();
    final firestoreService = context.read<FirestoreService>();
    final termId = termController.selectedTermId;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'QPI Calculator',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              color: AppColors.textMuted,
              tooltip: 'What is QPI?',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _showAboutDialog(context),
            ),
          ],
        ),
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

                // There's no real grade to judge yet if nothing has been
                // entered this semester AND no previous record was given —
                // both semesterQpi/cumulativeQpi would just be 0.0 in that
                // case, which is NOT a real "1.00 is best" grade and must
                // not be run through standingFor (0.00 would wrongly read
                // as "Excellent" since it's below the 1.75 cutoff).
                final hasSemesterData = records.isNotEmpty;
                final hasCumulativeData = hasSemesterData || _prevUnits > 0;

                final standing = hasCumulativeData
                    ? standingFor(
                        hasSemesterData ? cumulativeQpi : _prevQpi,
                        defaultGradeScale,
                      )
                    : null;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _QpiHeroCard(
                      semesterQpi: semesterQpi,
                      cumulativeQpi: cumulativeQpi,
                      standing: standing,
                      hasSemesterData: hasSemesterData,
                      hasCumulativeData: hasCumulativeData,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('This Semester', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          '${records.length} subject${records.length == 1 ? '' : 's'} · $semesterUnits units',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (records.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.pillLavender,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.menu_book_outlined, color: AppColors.navyDark),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'No subjects added yet.',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...records.map(
                        (r) => _SubjectCard(
                          record: r,
                          onEdit: () => _editSubject(context, termId, r),
                          onDelete: () => _removeSubject(context, termId, r.id),
                        ),
                      ),
                    const SizedBox(height: 12),
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
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.pillLavender,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.history_rounded, color: AppColors.navyDark, size: 18),
                        ),
                        title: const Text('Previous Record', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('For cumulative QPI', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                                    decoration: const InputDecoration(labelText: 'Previous QPI', hintText: 'e.g. 1.75'),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.navyDark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4)),
        ),
      ],
    );
  }
}

/// Navy-gradient hero card mirroring the Home screen's hero style. On this
/// scale **lower is better** (1.00 highest, 5.00 lowest). When there's
/// nothing entered yet, the numeric values are meaningless zeros — those
/// cases show "--" and a neutral "No Data" badge instead of running 0.00
/// through the standing thresholds (which would misread it as "Excellent").
class _QpiHeroCard extends StatelessWidget {
  final double semesterQpi;
  final double cumulativeQpi;
  final GradeStanding? standing;
  final bool hasSemesterData;
  final bool hasCumulativeData;

  const _QpiHeroCard({
    required this.semesterQpi,
    required this.cumulativeQpi,
    required this.standing,
    required this.hasSemesterData,
    required this.hasCumulativeData,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = standing == null ? AppColors.textMuted : AppColors.forTier(standing!.tier);
    final badgeLabel = standing?.label ?? 'No Data';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your QPI',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Semester QPI',
                  value: semesterQpi,
                  hasData: hasSemesterData,
                ),
              ),
              Container(width: 1, height: 44, color: Colors.white.withOpacity(0.18)),
              Expanded(
                child: _HeroStat(
                  label: 'Cumulative QPI',
                  value: cumulativeQpi,
                  hasData: hasCumulativeData,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1.00 is the highest possible QPI · 5.00 is failing',
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final double value;
  final bool hasData;
  const _HeroStat({required this.label, required this.value, required this.hasData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasData ? value.toStringAsFixed(2) : '--',
          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Replaces the old ListTile row: a colored accent bar plus a grade-point
/// badge, matching the pastel-card language used elsewhere in the app.
class _SubjectCard extends StatelessWidget {
  final GradeRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubjectCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scale = gradeScaleById(record.gradeScaleId);
    final standing = standingFor(record.grade, scale);
    final tierColor = AppColors.forTier(standing.tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: tierColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.subjectName.isEmpty ? record.subjectCode : record.subjectName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.units} unit${record.units == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              record.grade.toStringAsFixed(2),
              style: TextStyle(color: tierColor, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.textMuted,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.overdue,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}