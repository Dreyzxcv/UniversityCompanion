import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/class_session.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

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

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const windowsInit = WindowsInitializationSettings(
      appName: 'University Companion',
      appUserModelId: 'com.example.universityCompanionApp',
      guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        macOS: iosInit,
        windows: windowsInit,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
    _initialized = true;
  }

  /// Requests OS-level notification permission.
  /// Call this once, e.g. right after login.
  Future<bool> requestPermission() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  /// Schedules a notification 1 hour before [session] starts,
  /// repeating weekly.
  Future<void> scheduleClassReminder(ClassSession session) async {
    final scheduled = _nextOccurrenceMinusOneHour(session);

    if (scheduled == null) return;

    await _plugin.zonedSchedule(
      id: _notificationId(session.id),
      title: '${session.subjectCode} starts in 1 hour',
      body: '${session.startTime} - ${session.endTime}'
          '${session.room.isNotEmpty ? ' · ${session.room}' : ''}',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
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
    return _plugin.cancel(
      id: _notificationId(classId),
    );
  }

  Future<void> resyncAll(List<ClassSession> classes) async {
    await _plugin.cancelAll();

    for (final session in classes) {
      await scheduleClassReminder(session);
    }
  }

  int _notificationId(String classId) => classId.hashCode & 0x7fffffff;

  tz.TZDateTime? _nextOccurrenceMinusOneHour(
    ClassSession session,
  ) {
    const dayCodes = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ];

    final targetWeekday = dayCodes.indexOf(session.day) + 1;

    if (targetWeekday == 0) return null;

    final now = tz.TZDateTime.now(tz.local);

    final startParts = session.startTime.split(':');

    final startHour = int.tryParse(startParts[0]) ?? 8;

    final startMinute = int.tryParse(
          startParts.length > 1 ? startParts[1] : '0',
        ) ??
        0;

    for (int daysAhead = 0; daysAhead < 8; daysAhead++) {
      final candidateDay = now.add(Duration(days: daysAhead));

      if (candidateDay.weekday != targetWeekday) {
        continue;
      }

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
