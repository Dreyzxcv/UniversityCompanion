import 'package:flutter/material.dart';
import '../shared/models/grade_scale.dart';

class GradeScaleSection extends StatelessWidget {
  final GradeScale scale;
  const GradeScaleSection({super.key, this.scale = ateneoScale});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.list_alt_rounded),
        title: Text('Grade Scale — ${scale.name}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnFractionWidth(0.5),
                1: FlexColumnFractionWidth(0.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    _CellText('Letter Grade', bold: true),
                    _CellText('Grade Point', bold: true),
                  ],
                ),
                ...scale.entries.map(
                  (e) => TableRow(
                    children: [
                      _CellText(e.label),
                      _CellText(e.points.toStringAsFixed(2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  final String text;
  final bool bold;
  const _CellText(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }
}

// Table doesn't ship a flex-fraction column width helper, so provide a
// minimal one scaled against the table's constraints.
class FlexColumnFractionWidth extends TableColumnWidth {
  final double fraction;
  const FlexColumnFractionWidth(this.fraction);

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      containerWidth * fraction;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      containerWidth * fraction;
}
