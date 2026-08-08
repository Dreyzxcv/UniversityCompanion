import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/class_session.dart';

/// Schedules a weekly, repeating "class starts in 1 hour" notification
/// for each [ClassSession]. Notifications are recurring by day-of-week +
/// time (not one-off), matching how classes repeat every week within a
/// term.
///
/// Each class's stable notification id is derived from its Firestore doc
/// id (a UUID string), so scheduling the same class twice overwrites the
/// existing notification rather than creating a duplicate, and deleting
/// a class can cancel its notification by id alone.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'class_reminders';
  static const _channelName = 'Class Reminders';
  static const _channelDescription = 'Alerts before your classes start';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Falls back to the device's local timezone; good enough for a
    // single-timezone (PH) student app without pulling in a geolocation
    // dependency just to set this.
    tz.setLocalLocation(tz.local);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // requested explicitly below
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _plugin
        .resolvePlatformSpecificImplementation
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ));

    _initialized = true;
  }

  /// Requests OS-level notification permission. Call this once, e.g. right
  /// after login, rather than at every app launch.
  Future<bool> requestPermission() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  /// Schedules (or reschedules, if one already exists for this class) a
  /// notification 1 hour before [session] starts, repeating weekly.
  Future<void> scheduleClassReminder(ClassSession session) async {
    final scheduled = _nextOccurrenceMinusOneHour(session);
    if (scheduled == null) return; // e.g. class starts in < 1 hour already

    await _plugin.zonedSchedule(
      _notificationId(session.id),
      '${session.subjectCode} starts in 1 hour',
      '${session.startTime} - ${session.endTime}'
          '${session.room.isNotEmpty ? ' · ${session.room}' : ''}',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelClassReminder(String classId) {
    return _plugin.cancel(_notificationId(classId));
  }

  /// Re-syncs notifications for a full list of classes, e.g. on app start
  /// or after a bulk Firestore fetch. Cancels everything first so classes
  /// removed elsewhere (another device, direct Firestore edit) don't leave
  /// orphaned notifications behind.
  Future<void> resyncAll(List<ClassSession> classes) async {
    await _plugin.cancelAll();
    for (final session in classes) {
      await scheduleClassReminder(session);
    }
  }

  int _notificationId(String classId) => classId.hashCode & 0x7fffffff;

  /// Finds the next date/time this class meets, then subtracts 1 hour.
  /// Returns null if that reminder moment has already passed for today's
  /// occurrence and there's nothing else to compute against (shouldn't
  /// normally happen since we search forward up to 7 days).
  tz.TZDateTime? _nextOccurrenceMinusOneHour(ClassSession session) {
    const dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final targetWeekday = dayCodes.indexOf(session.day) + 1; // 1..7
    if (targetWeekday == 0) return null;

    final now = tz.TZDateTime.now(tz.local);
    final startParts = session.startTime.split(':');
    final startHour = int.tryParse(startParts[0]) ?? 8;
    final startMinute = int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0;

    for (int daysAhead = 0; daysAhead < 8; daysAhead++) {
      final candidateDay = now.add(Duration(days: daysAhead));
      if (candidateDay.weekday != targetWeekday) continue;

      final classStart = tz.TZDateTime(
        tz.local,
        candidateDay.year,
        candidateDay.month,
        candidateDay.day,
        startHour,
        startMinute,
      );
      final reminderTime = classStart.subtract(const Duration(hours: 1));
      if (reminderTime.isAfter(now)) {
        return reminderTime;
      }
    }
    return null;
  }

  @visibleForTesting
  int notificationIdForTest(String classId) => _notificationId(classId);
}