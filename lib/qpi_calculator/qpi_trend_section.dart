import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/models/grade_record.dart';
import '../shared/services/firestore_service.dart';
import '../shared/theme/app_theme.dart';

class QpiTrendSection extends StatefulWidget {
  final FirestoreService service;
  const QpiTrendSection({super.key, required this.service});

  @override
  State<QpiTrendSection> createState() => _QpiTrendSectionState();
}

class _QpiTrendSectionState extends State<QpiTrendSection> {
  late Future<List<SemesterResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SemesterResult>> _load() async {
    final snapshots = await widget.service.fetchAllTermGradeSnapshots();
    return snapshots.map((s) {
      final records = s['grades'] as List<GradeRecord>;
      return SemesterResult(
        termId: s['termId'],
        termLabel: s['termName'] ?? '',
        semesterQpi: computeSemesterQpi(records),
        semesterUnits: records.fold<num>(0, (sum, r) => sum + r.units),
      );
    }).toList();
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.pillLavender,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.show_chart_rounded, color: AppColors.navyDark, size: 18),
        ),
        title: const Text('QPI Trend', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('1.00 = best · 5.00 = worst', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        onExpansionChanged: (open) {
          if (open) _refresh();
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: FutureBuilder<List<SemesterResult>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final results = snapshot.data ?? [];
                if (results.length < 2) {
                  return SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        results.isEmpty
                            ? 'Save at least one semester to see your trend.'
                            : 'Save one more semester to see a trend line.',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final improving = results.last.semesterQpi <= results.first.semesterQpi;
                final lineColor = improving ? AppColors.excellent : AppColors.overdue;

                // Plot (6 - qpi) so the chart visually reads "up = better"
                // even though a *lower* QPI is the academically better one.
                double plot(double qpi) => 6.0 - qpi;

                return SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: 1,
                      maxY: 5,
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final actual = 6.0 - value; // undo the plot transform
                              return Text(actual.toStringAsFixed(2), style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= results.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  results[i].termLabel,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: lineColor,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: lineColor.withOpacity(0.08)),
                          spots: [
                            for (int i = 0; i < results.length; i++)
                              FlSpot(i.toDouble(), plot(results[i].semesterQpi)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}