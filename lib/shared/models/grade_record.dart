class GradeRecord {
  final String id;
  final String subjectCode;
  final String subjectName;
  final num units;
  final double grade; // grade point value, e.g. 4.0
  final String gradeScaleId;

  GradeRecord({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.units,
    required this.grade,
    required this.gradeScaleId,
  });

  factory GradeRecord.fromMap(String id, Map<String, dynamic> map) {
    return GradeRecord(
      id: id,
      subjectCode: map['subjectCode'] ?? '',
      subjectName: map['subjectName'] ?? '',
      units: map['units'] ?? 0,
      grade: (map['grade'] ?? 0).toDouble(),
      gradeScaleId: map['gradeScaleId'] ?? 'ateneo_4.0',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'units': units,
      'grade': grade,
      'gradeScaleId': gradeScaleId,
    };
  }
}

/// Result of a semester's QPI computation, used for the trend chart and
/// for the "Calculate & Save" summary. Not a Firestore document itself —
/// derived from a term's `grades` subcollection.
class SemesterResult {
  final String termId;
  final String termLabel;
  final double semesterQpi;
  final num semesterUnits;

  SemesterResult({
    required this.termId,
    required this.termLabel,
    required this.semesterQpi,
    required this.semesterUnits,
  });
}

/// Semester QPI = sum(units * grade) / sum(units)
double computeSemesterQpi(List<GradeRecord> records) {
  if (records.isEmpty) return 0.0;
  final totalUnits = records.fold<num>(0, (sum, r) => sum + r.units);
  if (totalUnits == 0) return 0.0;
  final weightedSum = records.fold<double>(
    0.0,
    (sum, r) => sum + (r.units * r.grade),
  );
  return weightedSum / totalUnits;
}

/// Cumulative QPI = ((prevQPI * prevUnits) + (semQPI * semUnits)) / (prevUnits + semUnits)
double computeCumulativeQpi({
  required double previousQpi,
  required num previousUnits,
  required double semesterQpi,
  required num semesterUnits,
}) {
  final totalUnits = previousUnits + semesterUnits;
  if (totalUnits == 0) return 0.0;
  return ((previousQpi * previousUnits) + (semesterQpi * semesterUnits)) /
      totalUnits;
}
