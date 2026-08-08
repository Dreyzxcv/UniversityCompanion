/// Formats a stored "HH:mm" (24-hour) time string for display, either
/// as-is (24-hour) or converted to 12-hour with AM/PM.
String formatTimeOfDay(String hhmm, {required bool is24Hour}) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

  if (is24Hour) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

/// Formats a range like "13:00 - 15:30" (24h) into either
/// "13:00 - 15:30" or "1:00 PM - 3:30 PM" depending on [is24Hour].
String formatTimeRange(String startHhmm, String endHhmm, {required bool is24Hour}) {
  return '${formatTimeOfDay(startHhmm, is24Hour: is24Hour)} - '
      '${formatTimeOfDay(endHhmm, is24Hour: is24Hour)}';
}