import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/term.dart';
import '../services/term_controller.dart';
import '../theme/app_theme.dart';

const List<String> kYearLevels = [
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
  '5th Year',
];

const List<String> kSemesterOptions = ['1st Sem', '2nd Sem', 'Summer'];

/// Pill button in the app bar that shows the active term and opens the
/// term picker / "new term" flow. Replaces the old bare DropdownButton
/// with something that matches the rest of the app's rounded, pastel
/// visual language (see AppColors / _NoTermCard / _SectionCard).
class TermSelector extends StatelessWidget {
  const TermSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TermController>();

    if (controller.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final selected = controller.selectedTerm;
    final hasTerms = controller.terms.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => hasTerms
            ? _showTermPicker(context, controller)
            : _showNewTermDialog(context, controller),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: hasTerms ? AppColors.navyDark : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  selected?.name ?? 'No terms yet',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasTerms ? AppColors.navyDark : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                hasTerms ? Icons.keyboard_arrow_down_rounded : Icons.add_circle_outline,
                size: 18,
                color: hasTerms ? AppColors.navyDark : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showTermPicker(BuildContext context, TermController controller) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => _TermPickerSheet(controller: controller),
  );
}

class _TermPickerSheet extends StatelessWidget {
  final TermController controller;
  const _TermPickerSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Your Terms',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                itemCount: controller.terms.length,
                itemBuilder: (context, i) {
                  final term = controller.terms[i];
                  final selected = term.id == controller.selectedTermId;
                  return _TermTile(
                    term: term,
                    selected: selected,
                    onTap: () {
                      controller.selectTerm(term.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 20, color: AppColors.cardBorder),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showNewTermDialog(context, controller);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Term'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermTile extends StatelessWidget {
  final Term term;
  final bool selected;
  final VoidCallback onTap;

  const _TermTile({required this.term, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? AppColors.pillLavender : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.navyDark : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: 18,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        term.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                      ),
                      if (term.schoolYear.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            term.schoolYear,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.navyDark, size: 20)
                else if (term.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showNewTermDialog(BuildContext context, TermController controller) async {
  final yearCtrl = TextEditingController();
  final customSemesterCtrl = TextEditingController();
  String yearLevel = kYearLevels.first;
  String? semester = kSemesterOptions.first;
  bool useCustomSemester = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final semesterValid =
            useCustomSemester ? customSemesterCtrl.text.trim().isNotEmpty : semester != null;

        final screenHeight = MediaQuery.of(ctx).size.height;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
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
                      child: const Icon(Icons.calendar_month_rounded, color: AppColors.navyDark),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'New Term',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set up the term you want to track.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),

                const _FieldLabel('Year level'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: yearLevel,
                  items: kYearLevels
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => yearLevel = v);
                  },
                ),
                const SizedBox(height: 18),

                const _FieldLabel('Semester'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...kSemesterOptions.map((s) {
                      final isSelected = !useCustomSemester && semester == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: isSelected,
                        onSelected: (_) => setDialogState(() {
                          useCustomSemester = false;
                          semester = s;
                        }),
                        selectedColor: AppColors.navyDark,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textDark,
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
                      selected: useCustomSemester,
                      onSelected: (_) => setDialogState(() => useCustomSemester = true),
                      selectedColor: AppColors.navyDark,
                      labelStyle: TextStyle(
                        color: useCustomSemester ? Colors.white : AppColors.textDark,
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
                if (useCustomSemester) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customSemesterCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'e.g. Trimester 1'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
                const SizedBox(height: 18),

                const _FieldLabel('School year'),
                const SizedBox(height: 6),
                TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. 2026-2027'),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: !semesterValid
                            ? null
                            : () {
                                final semesterLabel =
                                    useCustomSemester ? customSemesterCtrl.text.trim() : semester!;
                                final name = '$yearLevel · $semesterLabel';
                                controller.createTerm(name, yearCtrl.text.trim());
                                Navigator.pop(ctx);
                              },
                        child: const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
    );
  }
}