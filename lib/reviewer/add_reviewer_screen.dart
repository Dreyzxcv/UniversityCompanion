import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../shared/services/reviewer_service.dart';
import '../shared/theme/app_theme.dart';
import 'quiz_screen.dart';

enum _NotesSource { pasteText, uploadPdf }

class AddReviewerScreen extends StatefulWidget {
  const AddReviewerScreen({super.key});

  @override
  State<AddReviewerScreen> createState() => _AddReviewerScreenState();
}

class _AddReviewerScreenState extends State<AddReviewerScreen> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  int _numQuestions = 10;
  bool _generating = false;
  String? _error;

  _NotesSource _source = _NotesSource.pasteText;

  // PDF-specific state, kept separate from the generic _error above so
  // switching tabs doesn't leave a stale error from the other mode showing.
  bool _extractingPdf = false;
  String? _pdfFileName;
  String? _pdfError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _switchSource(_NotesSource source) {
    if (_source == source) return;
    setState(() {
      _source = source;
      _error = null;
      // Deliberately NOT clearing _textCtrl here: if someone uploads a PDF,
      // taps back to "Paste Text" to tweak a line, then switches back, the
      // extracted text should still be there rather than forcing a re-upload.
    });
  }

  Future<void> _pickAndExtractPdf() async {
    setState(() {
      _pdfError = null;
      _extractingPdf = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled the picker.
        setState(() => _extractingPdf = false);
        return;
      }

      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null) {
        throw Exception('Could not read the selected file.');
      }

      final document = PdfDocument(inputBytes: bytes);
      String extracted;
      try {
        extracted = PdfTextExtractor(document).extractText();
      } finally {
        document.dispose();
      }

      final cleaned = extracted.trim();

      if (cleaned.length < 50) {
        // Most likely a scanned PDF with no embedded text layer, or an
        // otherwise near-empty document — nothing worth quizzing on.
        setState(() {
          _pdfError = "Couldn't find enough readable text in this PDF. "
              "It may be a scanned document without selectable text — "
              "try a PDF exported from Word/Google Docs instead.";
          _pdfFileName = null;
          _extractingPdf = false;
        });
        return;
      }

      setState(() {
        _textCtrl.text = cleaned;
        _pdfFileName = picked.name;
        _extractingPdf = false;
      });
    } catch (e) {
      debugPrint('PDF extraction failed: $e');
      setState(() {
        _pdfError = 'Could not read that PDF. Please try a different file.';
        _extractingPdf = false;
      });
    }
  }

  void _clearPdf() {
    setState(() {
      _pdfFileName = null;
      _pdfError = null;
      _textCtrl.clear();
    });
  }

  Future<void> _generate() async {
    if (_titleCtrl.text.trim().isEmpty || _textCtrl.text.trim().length < 50) {
      setState(() => _error = _source == _NotesSource.uploadPdf
          ? 'Add a title and upload a PDF with enough readable text.'
          : 'Add a title and at least a few sentences of notes.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final service = context.read<ReviewerService>();
      final mcq = (_numQuestions * 0.5).round();
      final ident = (_numQuestions * 0.3).round();
      final enumr = _numQuestions - mcq - ident;

      final reviewerId = await service.generateQuizFromText(
        title: _titleCtrl.text.trim(),
        sourceText: _textCtrl.text.trim(),
        numQuestions: _numQuestions,
        numMcq: mcq,
        numIdentification: ident,
        numEnumeration: enumr,
      );

      if (mounted) {
        // Same rule as ReviewerListScreen: re-supply the provider to the
        // new route since Navigator.push/pushReplacement lands outside
        // this screen's provider scope.
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
      // TEMPORARY: print the full error to the debug console so we can
      // see exactly what's failing (Gemini call, parsing, or Firestore
      // write). Remove the debugPrint once the real cause is fixed and
      // replace _error with a clean user-facing message.
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
    return Scaffold(
      appBar: AppBar(title: const Text('New Reviewer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              enabled: !_generating,
              decoration: const InputDecoration(labelText: 'Title (e.g. "Thermo Ch. 3")'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Source material',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SourceToggleChip(
                    icon: Icons.notes_rounded,
                    label: 'Paste Text',
                    selected: _source == _NotesSource.pasteText,
                    onTap: _generating ? null : () => _switchSource(_NotesSource.pasteText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SourceToggleChip(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Upload PDF',
                    selected: _source == _NotesSource.uploadPdf,
                    onTap: _generating ? null : () => _switchSource(_NotesSource.uploadPdf),
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
                fileName: _pdfFileName,
                charCount: _textCtrl.text.trim().length,
                error: _pdfError,
                onPick: _generating ? null : _pickAndExtractPdf,
                onClear: _generating ? null : _clearPdf,
              ),
            const SizedBox(height: 18),
            Text('Number of questions: $_numQuestions',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _numQuestions.toDouble(),
              min: 5,
              max: 20,
              divisions: 15,
              label: '$_numQuestions',
              onChanged: _generating
                  ? null
                  : (v) => setState(() => _numQuestions = v.round()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.overdue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.overdue, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

/// Small pill-style toggle button used to switch between "Paste Text" and
/// "Upload PDF" — matches the ChoiceChip visual language used elsewhere
/// in the app (day pickers, grade pickers) rather than a plain TabBar.
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
      color: selected ? AppColors.navyDark : AppColors.pillLavender.withOpacity(0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.navyDark),
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

/// PDF upload state panel: pick button when empty, extracting spinner
/// mid-pick, and a summary card (filename + extracted length) once text
/// has been pulled from the file. Text is extracted entirely on-device
/// before anything is sent to Gemini — the PDF itself never leaves the
/// phone, only the extracted text does (same as pasted notes).
class _PdfUploadPanel extends StatelessWidget {
  final bool extracting;
  final String? fileName;
  final int charCount;
  final String? error;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  const _PdfUploadPanel({
    required this.extracting,
    required this.fileName,
    required this.charCount,
    required this.error,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.pillLavender.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFile ? AppColors.excellent.withOpacity(0.4) : AppColors.cardBorder,
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
                    Text('Reading PDF…', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                )
              : hasFile
                  ? Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.excellent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded,
                              color: AppColors.excellent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName!,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$charCount characters extracted',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textMuted,
                          tooltip: 'Remove PDF',
                          onPressed: onClear,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Icon(Icons.upload_file_rounded, color: AppColors.navyDark, size: 28),
                        const SizedBox(height: 10),
                        const Text(
                          'Upload a PDF of your reviewer',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Text-based PDFs work best (e.g. exported from Word or Docs).',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: onPick,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('Choose PDF File'),
                        ),
                      ],
                    ),
        ),
        if (hasFile && !extracting) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Choose a different file'),
            ),
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
              style: const TextStyle(color: AppColors.overdue, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}