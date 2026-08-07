/// A single row in a grade scale, e.g. "A" -> 4.0.
class GradeScaleEntry {
  final String label; // display label, e.g. "A" or "1.00"
  final double points; // grade point value

  const GradeScaleEntry(this.label, this.points);
}

/// A named, referenceable grade scale. Stored by id (gradeScaleId) so a
/// grade record only needs to reference the id, not embed the whole scale.
class GradeScale {
  final String id;
  final String name;
  final List<GradeScaleEntry> entries;

  const GradeScale({
    required this.id,
    required this.name,
    required this.entries,
  });

  double? pointsForLabel(String label) {
    for (final e in entries) {
      if (e.label == label) return e.points;
    }
    return null;
  }
}

/// Default scale: Ateneo de Manila's 4.0 QPI scale.
/// Kept as a static in-app registry for the MVP; a future phase can move
/// this into Firestore (e.g. `gradeScales/{gradeScaleId}`) without changing
/// how `grades` documents reference it, since they only store the id.
const GradeScale ateneoScale = GradeScale(
  id: 'ateneo_4.0',
  name: 'Ateneo 4.0 Scale',
  entries: [
    GradeScaleEntry('A', 4.0),
    GradeScaleEntry('B+', 3.5),
    GradeScaleEntry('B', 3.0),
    GradeScaleEntry('C+', 2.5),
    GradeScaleEntry('C', 2.0),
    GradeScaleEntry('D', 1.0),
    GradeScaleEntry('F', 0.0),
    GradeScaleEntry('W', 0.0),
  ],
);

/// Registry of available scales. Only one scale for the MVP, but the
/// `gradeScaleId` field on grade docs means more can be added later
/// (e.g. UP, DLSU) without restructuring existing data.
const Map<String, GradeScale> kGradeScales = {
  'ateneo_4.0': ateneoScale,
};

GradeScale gradeScaleById(String id) => kGradeScales[id] ?? ateneoScale;
