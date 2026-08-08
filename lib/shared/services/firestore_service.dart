import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/term.dart';
import '../models/class_session.dart';
import '../models/grade_record.dart';
import '../models/task_item.dart';

/// All reads/writes to `users/{uid}/terms/...` live here so the schedule
/// and QPI features don't each hand-roll Firestore paths.
class FirestoreService {
  final FirebaseFirestore _db;
  final String uid;

  FirestoreService({required this.uid, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _terms =>
      _db.collection('users').doc(uid).collection('terms');

  CollectionReference<Map<String, dynamic>> _classes(String termId) =>
      _terms.doc(termId).collection('classes');

  CollectionReference<Map<String, dynamic>> _grades(String termId) =>
      _terms.doc(termId).collection('grades');

  // ---------------- Terms ----------------

  Stream<List<Term>> watchTerms() {
    return _terms.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => Term.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<Term> createTerm({
    required String name,
    required String schoolYear,
    bool makeActive = true,
  }) async {
    if (makeActive) {
      await _deactivateAllTerms();
    }
    final ref = await _terms.add({
      'name': name,
      'schoolYear': schoolYear,
      'isActive': makeActive,
    });
    return Term(id: ref.id, name: name, schoolYear: schoolYear, isActive: makeActive);
  }

  Future<void> setActiveTerm(String termId) async {
    await _deactivateAllTerms();
    await _terms.doc(termId).update({'isActive': true});
  }

  Future<void> deleteTerm(String termId) async {
    final classesSnap = await _classes(termId).get();
    final gradesSnap = await _grades(termId).get();
    final tasksSnap = await _tasks(termId).get();

    final batch = _db.batch();
    for (final doc in classesSnap.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in gradesSnap.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in tasksSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_terms.doc(termId));

    await batch.commit();
  }

  Future<void> _deactivateAllTerms() async {
    final snap = await _terms.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    await batch.commit();
  }

  // ---------------- Classes ----------------

  Stream<List<ClassSession>> watchClasses(String termId) {
    return _classes(termId).snapshots().map(
          (snap) => snap.docs
              .map((d) => ClassSession.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<ClassSession>> fetchClassesOnce(String termId) async {
    final snap = await _classes(termId).get();
    return snap.docs.map((d) => ClassSession.fromMap(d.id, d.data())).toList();
  }

  Future<void> addClass(String termId, ClassSession session) {
    return _classes(termId).add(session.toMap());
  }

  Future<void> updateClass(String termId, ClassSession session) {
    return _classes(termId).doc(session.id).update(session.toMap());
  }

  Future<void> deleteClass(String termId, String classId) {
    return _classes(termId).doc(classId).delete();
  }

  CollectionReference<Map<String, dynamic>> _tasks(String termId) =>
      _terms.doc(termId).collection('tasks');

  // ---------------- Grades (QPI) ----------------

  Stream<List<GradeRecord>> watchGrades(String termId) {
    return _grades(termId).snapshots().map(
          (snap) => snap.docs
              .map((d) => GradeRecord.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addGrade(String termId, GradeRecord record) {
    return _grades(termId).add(record.toMap());
  }

  Future<void> updateGrade(String termId, GradeRecord record) {
    return _grades(termId).doc(record.id).update(record.toMap());
  }

  Future<void> deleteGrade(String termId, String gradeId) {
    return _grades(termId).doc(gradeId).delete();
  }

  /// For the QPI trend chart: pulls every term's grades and reduces each
  /// to a single semester QPI point, ordered by term name.
  Future<List<Map<String, dynamic>>> fetchAllTermGradeSnapshots() async {
    final termsSnap = await _terms.orderBy('name').get();
    final results = <Map<String, dynamic>>[];
    for (final termDoc in termsSnap.docs) {
      final gradesSnap = await _grades(termDoc.id).get();
      if (gradesSnap.docs.isEmpty) continue;
      results.add({
        'termId': termDoc.id,
        'termName': termDoc.data()['name'],
        'grades': gradesSnap.docs
            .map((d) => GradeRecord.fromMap(d.id, d.data()))
            .toList(),
      });
    }
    return results;
  }

  // ---------------- Tasks ----------------

  Stream<List<TaskItem>> watchTasks(String termId) {
    return _tasks(termId).orderBy('dueDate').snapshots().map(
          (snap) => snap.docs
              .map((d) => TaskItem.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addTask(String termId, TaskItem task) {
    return _tasks(termId).add(task.toMap());
  }

  Future<void> updateTask(String termId, TaskItem task) {
    return _tasks(termId).doc(task.id).update(task.toMap());
  }

  Future<void> deleteTask(String termId, String taskId) {
    return _tasks(termId).doc(taskId).delete();
  }
}
