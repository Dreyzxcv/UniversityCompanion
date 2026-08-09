import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/services/reviewer_service.dart';
import '../shared/theme/app_theme.dart';
import 'quiz_screen.dart';

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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_titleCtrl.text.trim().isEmpty || _textCtrl.text.trim().length < 50) {
      setState(() => _error = 'Add a title and at least a few sentences of notes.');
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
            const SizedBox(height: 14),
            TextField(
              controller: _textCtrl,
              enabled: !_generating,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Paste your notes here',
                alignLabelWithHint: true,
              ),
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