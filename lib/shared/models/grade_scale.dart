/// A single row in a grade scale, e.g. "1.00" -> 1.00 points.
class GradeScaleEntry {
  final String label; // display label, e.g. "1.00" or "A"
  final double points; // grade point value

  const GradeScaleEntry(this.label, this.points);
}

/// A named, referenceable grade scale. Stored by id (gradeScaleId) so a
/// grade record only needs to reference the id, not embed the whole scale.
class GradeScale {
  final String id;
  final String name;
  final List<GradeScaleEntry> entries;

  /// True when a *lower* point value is the better grade (e.g. the
  /// Philippine 1.00–5.00 scale, where 1.00 is highest and 5.00 is a
  /// failing grade). False for scales like a 4.0 GPA where higher is better.
  final bool lowerIsBetter;

  const GradeScale({
    required this.id,
    required this.name,
    required this.entries,
    this.lowerIsBetter = false,
  });

  double? pointsForLabel(String label) {
    for (final e in entries) {
      if (e.label == label) return e.points;
    }
    return null;
  }

  double get bestPoints => lowerIsBetter ? _min : _max;
  double get worstPoints => lowerIsBetter ? _max : _min;

  double get _max =>
      entries.map((e) => e.points).reduce((a, b) => a > b ? a : b);
  double get _min =>
      entries.map((e) => e.points).reduce((a, b) => a < b ? a : b);
}

/// Default scale: the Philippine university convention where **1.00 is
/// the highest (best) grade and 5.00 is a failing grade**.
/// Kept as a static in-app registry for the MVP; a future phase can move
/// this into Firestore (e.g. `gradeScales/{gradeScaleId}`) without changing
/// how `grades` documents reference it, since they only store the id.
const GradeScale phGradeScale = GradeScale(
  id: 'ph_1.00_5.00',
  name: 'Philippine 1.00–5.00 Scale',
  lowerIsBetter: true,
  entries: [
    GradeScaleEntry('1.00', 1.00),
    GradeScaleEntry('1.25', 1.25),
    GradeScaleEntry('1.50', 1.50),
    GradeScaleEntry('1.75', 1.75),
    GradeScaleEntry('2.00', 2.00),
    GradeScaleEntry('2.25', 2.25),
    GradeScaleEntry('2.50', 2.50),
    GradeScaleEntry('2.75', 2.75),
    GradeScaleEntry('3.00', 3.00),
    GradeScaleEntry('4.00', 4.00), // Conditional
    GradeScaleEntry('5.00', 5.00), // Failed
  ],
);

/// Kept around for a school that still uses a 4.0-is-best GPA — not the
/// default anymore, but still resolvable by id for old data.
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

/// The scale used for new grade records unless a record already
/// specifies a different `gradeScaleId`.
const GradeScale defaultGradeScale = phGradeScale;

/// Registry of available scales. `gradeScaleId` on grade docs means more
/// can be added later (e.g. UP, DLSU variants) without restructuring
/// existing data.
const Map<String, GradeScale> kGradeScales = {
  'ph_1.00_5.00': phGradeScale,
  'ateneo_4.0': ateneoScale,
};

GradeScale gradeScaleById(String id) => kGradeScales[id] ?? defaultGradeScale;

/// A grade's standing bucket, used to color-code badges and the QPI hero
/// card. tier 0 = best .. 3 = worst.
class GradeStanding {
  final String label;
  final int tier;
  const GradeStanding(this.label, this.tier);
}

GradeStanding standingFor(double points, GradeScale scale) {
  if (scale.lowerIsBetter) {
    if (points <= 1.75) return const GradeStanding('Excellent', 0);
    if (points <= 2.75) return const GradeStanding('Good', 1);
    if (points <= 3.00) return const GradeStanding('Passing', 2);
    return const GradeStanding('At Risk', 3);
  }
  final best = scale.bestPoints;
  final worst = scale.worstPoints;
  final normalized = best == worst ? 0.0 : (best - points) / (best - worst);
  if (normalized <= 0.25) return const GradeStanding('Excellent', 0);
  if (normalized <= 0.5) return const GradeStanding('Good', 1);
  if (normalized <= 0.75) return const GradeStanding('Passing', 2);
  return const GradeStanding('At Risk', 3);
}
