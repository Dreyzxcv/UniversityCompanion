import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../shared/models/quiz_question.dart';
import '../shared/models/class_session.dart';
import '../shared/services/reviewer_service.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/term_controller.dart';
import '../shared/theme/app_theme.dart';
import 'quiz_screen.dart';

enum _NotesSource { pasteText, uploadPdf }

class _PickedPdf {
  final String name;
  final String text;
  const _PickedPdf({required this.name, required this.text});
}

// ---------------------------------------------------------------------------
// Defaults and constraints
// ---------------------------------------------------------------------------

const int _kDefaultQuestions = 15;
const int _kMinQuestions = 5;
const int _kMaxQuestions = 50;

/// All types available for the user to toggle on/off.
const List<QuestionType> _kAllTypes = [
  QuestionType.multipleChoice,
  QuestionType.trueOrFalse,
  QuestionType.identification,
  QuestionType.fillInTheBlanks,
  QuestionType.enumeration,
];

/// Types enabled by default.
const Set<QuestionType> _kDefaultTypes = {
  QuestionType.multipleChoice,
  QuestionType.identification,
  QuestionType.enumeration,
};

class AddReviewerScreen extends StatefulWidget {
  const AddReviewerScreen({super.key});

  @override
  State<AddReviewerScreen> createState() => _AddReviewerScreenState();
}

class _AddReviewerScreenState extends State<AddReviewerScreen> {
  final _titleCtrl = TextEditingController();
  final _subjectCodeCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  int _numQuestions = _kDefaultQuestions;
  Set<QuestionType> _enabledTypes = Set.from(_kDefaultTypes);

  bool _generating = false;
  String? _error;

  _NotesSource _source = _NotesSource.pasteText;
  bool _extractingPdf = false;
  final List<_PickedPdf> _pdfFiles = [];
  String? _pdfError;

  // Classes loaded from the user's schedule for subject code suggestions
  List<ClassSession> _scheduleClasses = [];

  @override
  void initState() {
    super.initState();
    _loadScheduleClasses();
  }

  Future<void> _loadScheduleClasses() async {
    try {
      final firestoreService = context.read<FirestoreService>();
      final termController = context.read<TermController>();
      final termId = termController.selectedTermId;
      if (termId == null) return;
      final classes = await firestoreService.fetchClassesOnce(termId);
      if (mounted) {
        setState(() => _scheduleClasses = classes);
      }
    } catch (_) {
      // Not critical — suggestions just won't show
    }
  }

  /// Unique subject codes from the user's schedule, sorted alphabetically.
  List<String> get _subjectCodeSuggestions {
    final codes = _scheduleClasses
        .map((c) => c.subjectCode)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return codes;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCodeCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _switchSource(_NotesSource source) {
    if (_source == source) return;
    setState(() {
      _source = source;
      _error = null;
    });
  }

  void _toggleType(QuestionType type) {
    setState(() {
      if (_enabledTypes.contains(type)) {
        if (_enabledTypes.length > 1) _enabledTypes.remove(type);
      } else {
        _enabledTypes.add(type);
      }
    });
  }

  void _recomputeCombinedText() {
    _textCtrl.text = _pdfFiles
        .map((f) => '=== ${f.name} ===\n${f.text}')
        .join('\n\n');
  }

  Future<void> _pickAndExtractPdfs() async {
    setState(() {
      _pdfError = null;
      _extractingPdf = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _extractingPdf = false);
        return;
      }

      final newlyAdded = <_PickedPdf>[];
      final skipped = <String>[];

      for (final picked in result.files) {
        final bytes = picked.bytes;
        if (bytes == null) {
          skipped.add(picked.name);
          continue;
        }

        try {
          final document = PdfDocument(inputBytes: bytes);
          String extracted;
          try {
            extracted = PdfTextExtractor(document).extractText();
          } finally {
            document.dispose();
          }

          final cleaned = extracted.trim();
          if (cleaned.length < 50) {
            skipped.add(picked.name);
            continue;
          }

          newlyAdded.add(_PickedPdf(name: picked.name, text: cleaned));
        } catch (e) {
          debugPrint('PDF extraction failed for ${picked.name}: $e');
          skipped.add(picked.name);
        }
      }

      setState(() {
        _pdfFiles.addAll(newlyAdded);
        _recomputeCombinedText();
        _extractingPdf = false;
        if (skipped.isNotEmpty && newlyAdded.isEmpty) {
          _pdfError =
              "Couldn't find enough readable text in "
              "${skipped.length == 1 ? 'that file' : 'those files'}. "
              "They may be scanned documents without selectable text — "
              "try PDFs exported from Word/Google Docs instead.";
        } else if (skipped.isNotEmpty) {
          _pdfError = "Skipped ${skipped.length} file"
              "${skipped.length == 1 ? '' : 's'} with no readable text: "
              "${skipped.join(', ')}";
        } else {
          _pdfError = null;
        }
      });
    } catch (e) {
      debugPrint('PDF picking failed: $e');
      setState(() {
        _pdfError = 'Could not read those PDFs. Please try again.';
        _extractingPdf = false;
      });
    }
  }

  void _removePdf(int index) {
    setState(() {
      _pdfFiles.removeAt(index);
      _recomputeCombinedText();
      _pdfError = null;
    });
  }

  void _clearAllPdfs() {
    setState(() {
      _pdfFiles.clear();
      _pdfError = null;
      _textCtrl.clear();
    });
  }

  Map<QuestionType, int> _computeCounts() {
    final types = _kAllTypes.where(_enabledTypes.contains).toList();
    if (types.isEmpty) return {};
    final base = _numQuestions ~/ types.length;
    final remainder = _numQuestions % types.length;
    final counts = <QuestionType, int>{};
    for (int i = 0; i < types.length; i++) {
      counts[types[i]] = base + (i < remainder ? 1 : 0);
    }
    return counts;
  }

  Future<void> _generate() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _textCtrl.text.trim().length < 50) {
      setState(() => _error = _source == _NotesSource.uploadPdf
          ? 'Add a title and upload at least one PDF with enough readable text.'
          : 'Add a title and at least a few sentences of notes.');
      return;
    }
    if (_enabledTypes.isEmpty) {
      setState(() => _error = 'Select at least one question type.');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final service = context.read<ReviewerService>();
      final counts = _computeCounts();

      final subjectCode = _subjectCodeCtrl.text.trim();

      final reviewerId = await service.generateQuizFromText(
        title: _titleCtrl.text.trim(),
        sourceText: _textCtrl.text.trim(),
        subjectCode: subjectCode.isEmpty ? null : subjectCode,
        numQuestions: _numQuestions,
        typeCounts: counts,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Provider<ReviewerService>.value(
              value: service,
              child: QuizScreen(reviewerId: reviewerId),
            ),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('generateQuizFromText failed: $e');
      debugPrint('$stack');
      if (mounted) {
        setState(() => _error = 'Could not generate quiz:\n$e');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _computeCounts();
    final suggestions = _subjectCodeSuggestions;

    return Scaffold(
      appBar: AppBar(title: const Text('New Reviewer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Title ─────────────────────────────────────────────────────
            TextField(
              controller: _titleCtrl,
              enabled: !_generating,
              decoration: const InputDecoration(
                  labelText: 'Title (e.g. "Mobile Development")',),
            ),
            const SizedBox(height: 12),

            // ── Subject Code ───────────────────────────────────────────────
            TextField(
              controller: _subjectCodeCtrl,
              enabled: !_generating,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Subject code (optional)',
                hintText: 'e.g. CAP102, ITRACKB4',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),

            // Subject code chips from schedule
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((code) {
                  final isSelected = _subjectCodeCtrl.text.trim().toUpperCase() ==
                      code.toUpperCase();
                  return GestureDetector(
                    onTap: _generating
                        ? null
                        : () {
                            setState(() {
                              _subjectCodeCtrl.text =
                                  isSelected ? '' : code;
                            });
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.navyDark
                            : AppColors.pillLavender,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.navyDark
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: isSelected
                                ? Colors.white
                                : AppColors.navyDark,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            code,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    'From your current term\'s schedule',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            // ── Source toggle ──────────────────────────────────────────────
            const Text(
              'Source material',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SourceToggleChip(
                    icon: Icons.notes_rounded,
                    label: 'Paste Text',
                    selected: _source == _NotesSource.pasteText,
                    onTap: _generating
                        ? null
                        : () => _switchSource(_NotesSource.pasteText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SourceToggleChip(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Upload PDFs',
                    selected: _source == _NotesSource.uploadPdf,
                    onTap: _generating
                        ? null
                        : () => _switchSource(_NotesSource.uploadPdf),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_source == _NotesSource.pasteText)
              TextField(
                controller: _textCtrl,
                enabled: !_generating,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Paste your notes here',
                  alignLabelWithHint: true,
                ),
              )
            else
              _PdfUploadPanel(
                extracting: _extractingPdf,
                files: _pdfFiles,
                error: _pdfError,
                onPick: _generating ? null : _pickAndExtractPdfs,
                onRemove: _generating ? null : _removePdf,
                onClearAll: _generating ? null : _clearAllPdfs,
              ),

            const SizedBox(height: 22),

            // ── Question types ─────────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Question types',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message:
                      'Select which kinds of questions to include. '
                      'Questions are distributed evenly across selected types.',
                  child: Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kAllTypes.map((type) {
                final enabled = _enabledTypes.contains(type);
                final count = counts[type] ?? 0;
                return _TypeChip(
                  type: type,
                  enabled: enabled,
                  count: count,
                  onTap: _generating ? null : () => _toggleType(type),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            // ── Question count slider ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Number of questions',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navyDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_numQuestions',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
            Slider(
              value: _numQuestions.toDouble(),
              min: _kMinQuestions.toDouble(),
              max: _kMaxQuestions.toDouble(),
              divisions: _kMaxQuestions - _kMinQuestions,
              label: '$_numQuestions',
              onChanged: _generating
                  ? null
                  : (v) => setState(() => _numQuestions = v.round()),
            ),
            if (_numQuestions >= 40)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.passingWarn),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Longer quizzes may take a bit more time to generate.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.passingWarn),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Distribution preview ───────────────────────────────────────
            if (_enabledTypes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DistributionPreview(counts: counts),
            ],

            // ── Error ──────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.overdue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.overdue, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Generate button ────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_generating ? 'Generating…' : 'Generate Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type chip
// ---------------------------------------------------------------------------

class _TypeChip extends StatelessWidget {
  final QuestionType type;
  final bool enabled;
  final int count;
  final VoidCallback? onTap;

  const _TypeChip({
    required this.type,
    required this.enabled,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: type.description,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.navyDark
                : AppColors.pillLavender.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                type.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: enabled ? Colors.white : AppColors.textDark,
                ),
              ),
              if (enabled && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Distribution preview bar
// ---------------------------------------------------------------------------

class _DistributionPreview extends StatelessWidget {
  final Map<QuestionType, int> counts;

  const _DistributionPreview({required this.counts});

  static const _typeColors = {
    QuestionType.multipleChoice: Color(0xFF4A6FA5),
    QuestionType.trueOrFalse: Color(0xFF16A672),
    QuestionType.identification: Color(0xFF8B5CF6),
    QuestionType.fillInTheBlanks: Color(0xFFDB9A15),
    QuestionType.enumeration: Color(0xFFE0483E),
  };

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final entries = counts.entries.where((e) => e.value > 0).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pillLavender.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribution',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: entries.map((e) {
                final color = _typeColors[e.key] ?? AppColors.navyDark;
                return Expanded(
                  flex: e.value,
                  child: Container(height: 8, color: color),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: entries.map((e) {
              final color = _typeColors[e.key] ?? AppColors.navyDark;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${e.key.shortLabel} × ${e.value}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Source toggle chip
// ---------------------------------------------------------------------------

class _SourceToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SourceToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.navyDark
          : AppColors.pillLavender.withOpacity(0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.navyDark),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PDF upload panel
// ---------------------------------------------------------------------------

class _PdfUploadPanel extends StatelessWidget {
  final bool extracting;
  final List<_PickedPdf> files;
  final String? error;
  final VoidCallback? onPick;
  final ValueChanged<int>? onRemove;
  final VoidCallback? onClearAll;

  const _PdfUploadPanel({
    required this.extracting,
    required this.files,
    required this.error,
    required this.onPick,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final hasFiles = files.isNotEmpty;
    final totalChars =
        files.fold<int>(0, (sum, f) => sum + f.text.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.pillLavender.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFiles
                  ? AppColors.excellent.withOpacity(0.4)
                  : AppColors.cardBorder,
            ),
          ),
          child: extracting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Reading PDFs…',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                )
              : hasFiles
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < files.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _PdfFileRow(
                            file: files[i],
                            onRemove: onRemove == null
                                ? null
                                : () => onRemove!(i),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(height: 1, color: AppColors.cardBorder),
                        const SizedBox(height: 10),
                        Text(
                          '${files.length} chapter${files.length == 1 ? '' : 's'} · $totalChars characters total',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Icon(Icons.upload_file_rounded,
                            color: AppColors.navyDark, size: 28),
                        const SizedBox(height: 10),
                        const Text(
                          'Upload one or more PDFs',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add a PDF per chapter (Ch. 1, Ch. 2, ...) — text-based PDFs '
                          'work best, e.g. exported from Word or Docs.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: onPick,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('Choose PDF Files'),
                        ),
                      ],
                    ),
        ),
        if (hasFiles && !extracting) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Remove all'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.overdue),
              ),
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add more PDFs'),
              ),
            ],
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.overdue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              error!,
              style:
                  const TextStyle(color: AppColors.overdue, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _PdfFileRow extends StatelessWidget {
  final _PickedPdf file;
  final VoidCallback? onRemove;

  const _PdfFileRow({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.excellent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded,
              color: AppColors.excellent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${file.text.length} characters',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.textMuted,
          tooltip: 'Remove ${file.name}',
          onPressed: onRemove,
        ),
      ],
    );
  }
}