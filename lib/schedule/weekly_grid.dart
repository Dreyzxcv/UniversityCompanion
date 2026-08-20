import 'package:flutter/material.dart';
import '../shared/models/class_session.dart';
import 'package:provider/provider.dart';
import '../shared/services/time_format_controller.dart';
import '../shared/utils/time_format.dart';
import '../shared/theme/app_theme.dart';
import '../shared/services/schedule_display_controller.dart';

const double _hourHeight = 68.0;
const double _dayColumnWidth = 118.0;
const double _timeColumnWidth = 48.0;
const int _fallbackStartHour = 7;
const int _fallbackEndHour = 20;
const int _hourPadding = 1;

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
  final _bodyHorizontal = ScrollController();
  final _bodyVertical = ScrollController();
  final _headerHorizontal = ScrollController();
  final _timeVertical = ScrollController();

  // Repaints the current-time indicator every minute
  late final Stream<DateTime> _tickStream;

  @override
  void initState() {
    super.initState();
    _bodyHorizontal.addListener(_syncHeader);
    _bodyVertical.addListener(_syncTime);

    // Tick every 60s so the time line stays accurate
    _tickStream = Stream.periodic(
      const Duration(seconds: 30),
      (_) => DateTime.now(),
    ).asBroadcastStream();
  }

  void _syncHeader() {
    if (!_headerHorizontal.hasClients) return;
    final offset = _bodyHorizontal.offset
        .clamp(0.0, _headerHorizontal.position.maxScrollExtent);
    if (_headerHorizontal.offset != offset) _headerHorizontal.jumpTo(offset);
  }

  void _syncTime() {
    if (!_timeVertical.hasClients) return;
    final offset = _bodyVertical.offset
        .clamp(0.0, _timeVertical.position.maxScrollExtent);
    if (_timeVertical.offset != offset) _timeVertical.jumpTo(offset);
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

  (int start, int end) get _hourRange {
    if (widget.classes.isEmpty) {
      return (_fallbackStartHour, _fallbackEndHour);
    }
    var minStart = 24, maxEnd = 0;
    for (final s in widget.classes) {
      final sh = s.startMinutes ~/ 60;
      final eh = (s.endMinutes / 60).ceil();
      if (sh < minStart) minStart = sh;
      if (eh > maxEnd) maxEnd = eh;
    }
    final start = (minStart - _hourPadding).clamp(0, 23);
    final end = (maxEnd + _hourPadding).clamp(start + 1, 24);
    return (start, end);
  }

  double _nowTopOffset(int startHour) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    return ((nowMinutes - startHour * 60) / 60) * _hourHeight;
  }

  bool _isTodayColumn(String dayCode) {
    const dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon
    return dayCodes.indexOf(dayCode) == todayIndex;
  }

  @override
  Widget build(BuildContext context) {
    final is24Hour = context.watch<TimeFormatController>().is24Hour;
    final showTimeIndicatorPref = context.watch<ScheduleDisplayController>().showTimeIndicator; 
    final (startHour, endHour) = _hourRange;
    final totalHeight = (endHour - startHour) * _hourHeight;
    final totalWidth = _dayColumnWidth * kWeekDays.length;
    final isDark = context.isDark;

    return StreamBuilder<DateTime>(
      stream: _tickStream,
      initialData: DateTime.now(),
      builder: (context, _) {
        final nowTop = _nowTopOffset(startHour);
        final showTimeLine =
            showTimeIndicatorPref && nowTop >= 0 && nowTop <= totalHeight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Day header row ──────────────────────────────────────────
            Row(
              children: [
                SizedBox(width: _timeColumnWidth),
                Expanded(
                  child: ClipRect(
                    child: SingleChildScrollView(
                      controller: _headerHorizontal,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: _buildHeaderRow(isDark),
                    ),
                  ),
                ),
              ],
            ),
            Divider(
              height: 1,
              color: context.gridLine,
            ),

            // ── Grid body ───────────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pinned time column
                  ClipRect(
                    child: SingleChildScrollView(
                      controller: _timeVertical,
                      physics: const NeverScrollableScrollPhysics(),
                      child: _buildTimeColumn(
                          startHour, endHour, totalHeight, is24Hour, isDark),
                    ),
                  ),

                  // Scrollable grid
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
                            clipBehavior: Clip.none,
                            children: [
                              // Day column backgrounds
                              _buildDayBackgrounds(
                                  startHour, endHour, totalHeight, isDark),

                              // Hour grid lines
                              _buildHourLines(
                                  startHour, endHour, totalHeight, isDark),

                              // Class blocks
                              ...widget.classes.map((s) =>
                                  _buildClassBlock(s, startHour, is24Hour, isDark)),

                              // Current time indicator
                              if (showTimeLine)
                                _buildTimeIndicator(nowTop, totalWidth),
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
      },
    );
  }

  Widget _buildHeaderRow(bool isDark) {
    return Row(
      children: kWeekDays.map((d) {
        final isToday = _isTodayColumn(d);
        return SizedBox(
          width: _dayColumnWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isToday)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.navyDark,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _dayLabel(d),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    _dayLabel(d),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark
                          ? AppColorsDark.textMuted
                          : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeColumn(
    int startHour,
    int endHour,
    double totalHeight,
    bool is24Hour,
    bool isDark,
  ) {
    final hours = endHour - startHour;
    return SizedBox(
      width: _timeColumnWidth,
      height: totalHeight,
      child: Stack(
        children: List.generate(hours, (i) {
          final hour = startHour + i;
          final label = formatTimeOfDay(
            '${hour.toString().padLeft(2, '0')}:00',
            is24Hour: is24Hour,
          );
          return Positioned(
            top: i * _hourHeight - 7,
            left: 0,
            right: 4,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColorsDark.textMuted
                    : AppColors.textMuted,
                letterSpacing: -0.3,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayBackgrounds(
    int startHour,
    int endHour,
    double totalHeight,
    bool isDark,
  ) {
    return Positioned.fill(
      child: Row(
        children: kWeekDays.map((d) {
          final isToday = _isTodayColumn(d);
          return Container(
            width: _dayColumnWidth,
            height: totalHeight,
            decoration: BoxDecoration(
              color: isToday
                  ? (isDark
                      ? AppColors.navyDark.withOpacity(0.18)
                      : AppColors.navyDark.withOpacity(0.035))
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isDark
                      ? AppColorsDark.cardBorder
                      : AppColors.cardBorder,
                  width: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHourLines(
    int startHour,
    int endHour,
    double totalHeight,
    bool isDark,
  ) {
    final hours = endHour - startHour;
    return SizedBox(
      width: _dayColumnWidth * kWeekDays.length,
      height: totalHeight,
      child: Column(
        children: List.generate(hours, (i) {
          return SizedBox(
            height: _hourHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Divider(
                height: 1,
                color: isDark
                    ? AppColorsDark.cardBorder.withOpacity(0.5)
                    : AppColors.cardBorder,
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Red time indicator: a horizontal line with a dot on the left
  Widget _buildTimeIndicator(double topOffset, double totalWidth) {
    return Positioned(
      top: topOffset - 1,
      left: 0,
      width: totalWidth,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.overdue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.overdue.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: AppColors.overdue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassBlock(
    ClassSession session,
    int startHour,
    bool is24Hour,
    bool isDark,
  ) {
    final dayIndex = kWeekDays.indexOf(session.day);
    if (dayIndex == -1) return const SizedBox.shrink();

    final top =
        ((session.startMinutes - startHour * 60) / 60) * _hourHeight;
    final height =
        ((session.endMinutes - session.startMinutes) / 60) * _hourHeight;

    // Derive a slightly darker shade for the left border accent
    final baseColor = session.colorValue;
    final darkAccent = HSLColor.fromColor(baseColor)
        .withLightness(
          (HSLColor.fromColor(baseColor).lightness - 0.18).clamp(0.0, 1.0),
        )
        .toColor();

    // Text color: dark on light cards, light on dark cards
    final luminance = baseColor.computeLuminance();
    final textColor = luminance > 0.45 ? AppColors.textDark : Colors.white;
    final subTextColor = textColor.withOpacity(0.72);

    final isShort = height < 52;

    return Positioned(
      left: dayIndex * _dayColumnWidth + 4,
      top: top.clamp(0, double.infinity),
      width: _dayColumnWidth - 8,
      height: height.clamp(24, double.infinity),
      child: GestureDetector(
        onTap: () => widget.onTapClass(session),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: darkAccent, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            8,
            isShort ? 4 : 7,
            6,
            isShort ? 4 : 7,
          ),
          child: isShort
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.subjectCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.startTime,
                      style: TextStyle(
                        fontSize: 9,
                        color: subTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subjectCode,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: textColor,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (session.subjectName.isNotEmpty && height > 66)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          session.subjectName,
                          style: TextStyle(
                            fontSize: 10,
                            color: subTextColor,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 9,
                          color: subTextColor,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            formatTimeRange(
                              session.startTime,
                              session.endTime,
                              is24Hour: is24Hour,
                            ),
                            style: TextStyle(
                              fontSize: 9,
                              color: subTextColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (session.room.isNotEmpty && height > 80)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.door_front_door_outlined,
                              size: 9,
                              color: subTextColor,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                session.room,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: subTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  String _dayLabel(String code) {
    const map = {
      'MON': 'Mon',
      'TUE': 'Tue',
      'WED': 'Wed',
      'THU': 'Thu',
      'FRI': 'Fri',
      'SAT': 'Sat',
    };
    return map[code] ?? code;
  }
}