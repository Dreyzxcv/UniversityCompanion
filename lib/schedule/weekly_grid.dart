import 'package:flutter/material.dart';
import '../shared/models/class_session.dart';
import 'package:provider/provider.dart';
import '../shared/services/time_format_controller.dart';
import '../shared/utils/time_format.dart';

const double _hourHeight = 64;
const double _dayColumnWidth = 120;
const double _timeColumnWidth = 52;

// Fallback range used only when there are no classes at all to derive a
// range from (WeeklyGrid is normally only built once classes.isNotEmpty,
// but keep a sane default just in case).
const int _fallbackStartHour = 7; // 7am
const int _fallbackEndHour = 20; // 8pm

// Padding (in whole hours) added before the earliest class and after the
// latest one, so a block doesn't sit flush against the very top/bottom
// edge of the grid.
const int _hourPadding = 1;

/// Calendar-style weekly grid, Monday-Saturday, time on the vertical axis.
/// Each class renders as a positioned colored block sized to its duration.
///
/// The day-name header row stays pinned at the top and the time-of-day
/// column stays pinned on the left, no matter how far the grid body has
/// been scrolled — otherwise a block far down/right (like a single
/// afternoon lab) has no visible reference for which day or time it's in.
///
/// The visible hour range is also derived from the actual classes rather
/// than a fixed 7am–8pm span: if every class for the term falls between
/// 1pm and 3pm, there's no reason to render (and force scrolling through)
/// empty rows from 7am–12pm and 4pm–8pm.
class WeeklyGrid extends StatefulWidget {
  final List<ClassSession> classes;
  final void Function(ClassSession) onTapClass;

  const WeeklyGrid({
    super.key,
    required this.classes,
    required this.onTapClass,
  });

  @override
  State<WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends State<WeeklyGrid> {
  // The body is the only surface the user actually drags. The header row
  // and time column use controllers that we keep in lockstep with the
  // body's controllers via listeners, so they visually track the scroll
  // without being draggable themselves (dragging a header/label column
  // directly would be a confusing UX).
  final _bodyHorizontal = ScrollController();
  final _bodyVertical = ScrollController();
  final _headerHorizontal = ScrollController();
  final _timeVertical = ScrollController();

  @override
  void initState() {
    super.initState();
    _bodyHorizontal.addListener(_syncHeader);
    _bodyVertical.addListener(_syncTime);
  }

  void _syncHeader() {
    if (!_headerHorizontal.hasClients) return;
    final offset = _bodyHorizontal.offset.clamp(
      0.0,
      _headerHorizontal.position.maxScrollExtent,
    );
    if (_headerHorizontal.offset != offset) {
      _headerHorizontal.jumpTo(offset);
    }
  }

  void _syncTime() {
    if (!_timeVertical.hasClients) return;
    final offset = _bodyVertical.offset.clamp(
      0.0,
      _timeVertical.position.maxScrollExtent,
    );
    if (_timeVertical.offset != offset) {
      _timeVertical.jumpTo(offset);
    }
  }

  @override
  void dispose() {
    _bodyHorizontal.removeListener(_syncHeader);
    _bodyVertical.removeListener(_syncTime);
    _bodyHorizontal.dispose();
    _bodyVertical.dispose();
    _headerHorizontal.dispose();
    _timeVertical.dispose();
    super.dispose();
  }

  /// Earliest class-start hour and latest class-end hour across the whole
  /// week (all days combined, since every day shares the same vertical
  /// axis), padded by [_hourPadding] on each side and clamped to a valid
  /// 0–24 range. Recomputed on every build so it stays in sync as classes
  /// are added/edited/removed.
  (int start, int end) get _hourRange {
    if (widget.classes.isEmpty) {
      return (_fallbackStartHour, _fallbackEndHour);
    }

    var minStartHour = 24;
    var maxEndHour = 0;
    for (final session in widget.classes) {
      final startHour = session.startMinutes ~/ 60;
      final endHour = (session.endMinutes / 60).ceil();
      if (startHour < minStartHour) minStartHour = startHour;
      if (endHour > maxEndHour) maxEndHour = endHour;
    }

    final start = (minStartHour - _hourPadding).clamp(0, 23);
    final end = (maxEndHour + _hourPadding).clamp(start + 1, 24);
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    final is24Hour = context.watch<TimeFormatController>().is24Hour;
    final (startHour, endHour) = _hourRange;
    final totalHeight = (endHour - startHour) * _hourHeight;
    final totalWidth = _dayColumnWidth * kWeekDays.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pinned header row: empty corner + horizontally-synced day labels.
        Row(
          children: [
            const SizedBox(width: _timeColumnWidth),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  controller: _headerHorizontal,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildHeaderRow(),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        // Pinned time column (left) + scrollable grid body (right).
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRect(
                child: SingleChildScrollView(
                  controller: _timeVertical,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildTimeLines(startHour, endHour, totalHeight, is24Hour)
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  controller: _bodyVertical,
                  child: SingleChildScrollView(
                    controller: _bodyHorizontal,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalWidth,
                      height: totalHeight,
                      child: Stack(
                        children: [
                          _buildDayColumns(startHour, endHour, totalHeight),
                          ...widget.classes.map((s) => _buildClassBlock(s, startHour, is24Hour)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: kWeekDays.map(
        (d) => Container(
          width: _dayColumnWidth,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: Text(
            _dayLabel(d),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildTimeLines(int startHour, int endHour, double totalHeight, bool is24Hour) {
    final hours = endHour - startHour;
    return SizedBox(
      width: _timeColumnWidth,
      height: totalHeight,
      child: Column(
        children: List.generate(hours, (i) {
          final hour = startHour + i;
          final label = formatTimeOfDay('${hour.toString().padLeft(2, '0')}:00', is24Hour: is24Hour);
          return SizedBox(
            height: _hourHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumns(int startHour, int endHour, double totalHeight) {
    return Positioned(
      left: 0,
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
              children: List.generate(endHour - startHour, (_) {
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

  Widget _buildClassBlock(ClassSession session, int startHour, bool is24Hour) {
    final dayIndex = kWeekDays.indexOf(session.day);
    if (dayIndex == -1) return const SizedBox.shrink();

    final top = ((session.startMinutes - startHour * 60) / 60) * _hourHeight;
    final height = ((session.endMinutes - session.startMinutes) / 60) * _hourHeight;

    return Positioned(
      left: dayIndex * _dayColumnWidth + 2,
      top: top.clamp(0, double.infinity),
      width: _dayColumnWidth - 4,
      height: height.clamp(28, double.infinity),
      child: GestureDetector(
        onTap: () => widget.onTapClass(session),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: session.colorValue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(session.subjectCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                if (session.subjectName.isNotEmpty)
                  Text(session.subjectName,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis, maxLines: 2),
                if (session.professor.isNotEmpty)
                  Text(session.professor,
                      style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                if (session.room.isNotEmpty)
                  Text(session.room,
                      style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                Text(
                  formatTimeRange(session.startTime, session.endTime, is24Hour: is24Hour),
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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