import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/term.dart';
import 'firestore_service.dart';

/// Drives the term selector dropdown used by both the Schedule and QPI
/// Calculator screens, so switching terms in one place is reflected in
/// both features (they read/write the same term subcollections).
class TermController extends ChangeNotifier {
  final FirestoreService _service;
  StreamSubscription<List<Term>>? _sub;

  List<Term> _terms = [];
  String? _selectedTermId;
  bool _loading = true;

  TermController(this._service) {
    _sub = _service.watchTerms().listen(_onTerms);
  }

  List<Term> get terms => _terms;
  bool get loading => _loading;
  Term? get selectedTerm =>
      _terms.where((t) => t.id == _selectedTermId).firstOrNull;
  String? get selectedTermId => _selectedTermId;

  void _onTerms(List<Term> terms) {
    _terms = terms;
    _loading = false;

    if (_selectedTermId == null || !terms.any((t) => t.id == _selectedTermId)) {
      final active = terms.where((t) => t.isActive).firstOrNull;
      _selectedTermId = active?.id ?? (terms.isNotEmpty ? terms.first.id : null);
    }
    notifyListeners();
  }

  void selectTerm(String termId) {
    if (termId == _selectedTermId) return;
    _selectedTermId = termId;
    notifyListeners();
  }

  Future<void> createTerm(String name, String schoolYear) async {
    final term = await _service.createTerm(name: name, schoolYear: schoolYear);
    _selectedTermId = term.id;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
