import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/models/grade_record.dart';
import '../shared/services/firestore_service.dart';

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
        leading: const Icon(Icons.show_chart_rounded),
        title: const Text('QPI Trend'),
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
                return SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 4,
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 1),
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
                          color: Colors.indigo,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          spots: [
                            for (int i = 0; i < results.length; i++)
                              FlSpot(i.toDouble(), results[i].semesterQpi),
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
