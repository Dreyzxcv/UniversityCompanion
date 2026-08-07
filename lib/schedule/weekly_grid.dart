import 'package:flutter/material.dart';
import '../shared/models/class_session.dart';

const double _hourHeight = 64;
const int _startHour = 7; // 7am
const int _endHour = 20; // 8pm
const double _dayColumnWidth = 120;
const double _timeColumnWidth = 52;

/// Calendar-style weekly grid, Monday-Saturday, time on the vertical axis.
/// Each class renders as a positioned colored block sized to its duration.
class WeeklyGrid extends StatelessWidget {
  final List<ClassSession> classes;
  final void Function(ClassSession) onTapClass;

  const WeeklyGrid({
    super.key,
    required this.classes,
    required this.onTapClass,
  });

  @override
  Widget build(BuildContext context) {
    final totalHeight = (_endHour - _startHour) * _hourHeight;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _timeColumnWidth + _dayColumnWidth * kWeekDays.length,
          child: Column(
            children: [
              _buildHeaderRow(),
              SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    _buildTimeLines(totalHeight),
                    _buildDayColumns(totalHeight),
                    ...classes.map(_buildClassBlock),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        SizedBox(width: _timeColumnWidth),
        ...kWeekDays.map(
          (d) => Container(
            width: _dayColumnWidth,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              _dayLabel(d),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeLines(double totalHeight) {
    final hours = _endHour - _startHour;
    return Positioned(
      left: 0,
      top: 0,
      child: SizedBox(
        width: _timeColumnWidth,
        height: totalHeight,
        child: Column(
          children: List.generate(hours, (i) {
            final hour = _startHour + i;
            final label = hour <= 12 ? '$hour${hour == 12 ? 'pm' : 'am'}' : '${hour - 12}pm';
            return SizedBox(
              height: _hourHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDayColumns(double totalHeight) {
    return Positioned(
      left: _timeColumnWidth,
      top: 0,
      child: Row(
        children: kWeekDays.map((_) {
          return Container(
            width: _dayColumnWidth,
            height: totalHeight,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: List.generate(_endHour - _startHour, (_) {
                return Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                );
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClassBlock(ClassSession session) {
    final dayIndex = kWeekDays.indexOf(session.day);
    if (dayIndex == -1) return const SizedBox.shrink();

    final top = ((session.startMinutes - _startHour * 60) / 60) * _hourHeight;
    final height = ((session.endMinutes - session.startMinutes) / 60) * _hourHeight;

    return Positioned(
      left: _timeColumnWidth + dayIndex * _dayColumnWidth + 2,
      top: top.clamp(0, double.infinity),
      width: _dayColumnWidth - 4,
      height: height.clamp(28, double.infinity),
      child: GestureDetector(
        onTap: () => onTapClass(session),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: session.colorValue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.subjectCode,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              if (session.section.isNotEmpty)
                Text(session.section, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
              if (session.room.isNotEmpty)
                Text(session.room, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(String code) {
    const map = {
      'MON': 'Mon', 'TUE': 'Tue', 'WED': 'Wed',
      'THU': 'Thu', 'FRI': 'Fri', 'SAT': 'Sat',
    };
    return map[code] ?? code;
  }
}
