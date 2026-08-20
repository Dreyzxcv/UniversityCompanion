import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/class_session.dart';
import '../models/task_item.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'class_reminders';
  static const String _channelName = 'Class & Task Reminders';
  static const String _channelDescription =
      'Alerts for classes and tasks';

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database.
    tz_data.initializeTimeZones();

    // Get and configure the device timezone.
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(
      tz.getLocation(timezoneInfo.identifier),
    );

    // Android initialization.
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization.
    const DarwinInitializationSettings iosInit =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // Windows initialization.
    const WindowsInitializationSettings windowsInit =
        WindowsInitializationSettings(
      appName: 'University Companion',
      appUserModelId: 'com.example.universityCompanionApp',
      guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        macOS: iosInit,
        windows: windowsInit,
      ),
    );

    // Create Android notification channel.
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    _initialized = true;
  }

  // ── Permission ───────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    // iOS permissions.
    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    final bool? iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android permissions.
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ notification permission.
    final bool? androidGranted =
        await androidPlugin?.requestNotificationsPermission();

    // Android exact alarm permission.
    final bool? exactAlarmGranted =
        await androidPlugin?.requestExactAlarmsPermission();

    return (iosGranted ?? true) &&
        (androidGranted ?? true) &&
        (exactAlarmGranted ?? true);
  }

  /// Checks whether exact alarms are currently allowed.
  ///
  /// Call this when the app resumes from the background/settings.
  Future<bool> hasExactAlarmPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? canSchedule =
        await androidPlugin?.canScheduleExactNotifications();

    return canSchedule ?? true;
  }

  // ── Class reminders ──────────────────────────────────────────────────────

  /// Schedules a reminder for every upcoming occurrence of this class
  /// within the next 8 days.
  Future<void> scheduleClassReminder(
    ClassSession session, {
    int minutesBefore = 60,
  }) async {
    await cancelClassReminder(session.id);

    final List<tz.TZDateTime> occurrences =
        _nextOccurrences(
      session,
      minutesBefore,
      days: 8,
    );

    for (int i = 0; i < occurrences.length; i++) {
      final tz.TZDateTime reminderTime = occurrences[i];

      if (reminderTime.isBefore(
        tz.TZDateTime.now(tz.local),
      )) {
        continue;
      }

      await _scheduleNotification(
        id: _notificationId(
          session.id,
          offset: i,
        ),
        title:
            '${session.subjectCode} starts in ${_describeMinutes(minutesBefore)}',
        body:
            '${session.startTime} – ${session.endTime}'
            '${session.room.isNotEmpty ? ' · ${session.room}' : ''}',
        scheduledDate: reminderTime,
      );
    }
  }

  Future<void> cancelClassReminder(String classId) async {
    // Cancel all possible occurrences for this class.
    for (int i = 0; i < 8; i++) {
      await _plugin.cancel(
        id: _notificationId(
          classId,
          offset: i,
        ),
      );
    }
  }

  Future<void> resyncAll(
    List<ClassSession> classes, {
    int minutesBefore = 60,
  }) async {
    await _plugin.cancelAll();

    for (final ClassSession session in classes) {
      await scheduleClassReminder(
        session,
        minutesBefore: minutesBefore,
      );
    }
  }

  // ── Task reminders ───────────────────────────────────────────────────────

  Future<void> scheduleTaskReminder(
    TaskItem task, {
    int daysBefore = 1,
  }) async {
    if (task.isCompleted) {
      await cancelTaskReminder(task.id);
      return;
    }

    final DateTime due = task.dueDate;

    // 6 PM on the reminder day.
    final tz.TZDateTime reminderTime = tz.TZDateTime(
      tz.local,
      due.year,
      due.month,
      due.day,
      18,
    ).subtract(
      Duration(days: daysBefore),
    );

    final tz.TZDateTime now =
        tz.TZDateTime.now(tz.local);

    if (reminderTime.isBefore(now)) {
      return;
    }

    await _scheduleNotification(
      id: _taskNotificationId(task.id),
      title:
          '${task.type.label} due ${daysBefore == 1 ? 'tomorrow' : 'in $daysBefore days'}',
      body: task.title,
      scheduledDate: reminderTime,
    );
  }

  Future<void> cancelTaskReminder(String taskId) {
    return _plugin.cancel(
      id: _taskNotificationId(taskId),
    );
  }

  // ── Core scheduling ──────────────────────────────────────────────────────

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint(
        'Exact notification failed, trying inexact: $e',
      );

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode:
              AndroidScheduleMode.inexact,
        );
      } catch (e2) {
        debugPrint(
          'Notification scheduling failed entirely: $e2',
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns all reminder times for [session] within the next [days] days.
  List<tz.TZDateTime> _nextOccurrences(
    ClassSession session,
    int minutesBefore, {
    int days = 8,
  }) {
    const List<String> dayCodes = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ];

    final int targetWeekday =
        dayCodes.indexOf(session.day) + 1;

    if (targetWeekday == 0) {
      return <tz.TZDateTime>[];
    }

    final List<String> startParts =
        session.startTime.split(':');

    final int startHour =
        int.tryParse(startParts[0]) ?? 8;

    final int startMinute =
        int.tryParse(
              startParts.length > 1
                  ? startParts[1]
                  : '0',
            ) ??
            0;

    final tz.TZDateTime now =
        tz.TZDateTime.now(tz.local);

    final List<tz.TZDateTime> results =
        <tz.TZDateTime>[];

    for (
      int daysAhead = 0;
      daysAhead < days;
      daysAhead++
    ) {
      final tz.TZDateTime candidate =
          now.add(Duration(days: daysAhead));

      if (candidate.weekday != targetWeekday) {
        continue;
      }

      final tz.TZDateTime classStart =
          tz.TZDateTime(
        tz.local,
        candidate.year,
        candidate.month,
        candidate.day,
        startHour,
        startMinute,
      );

      final tz.TZDateTime reminderTime =
          classStart.subtract(
        Duration(minutes: minutesBefore),
      );

      if (reminderTime.isAfter(now)) {
        results.add(reminderTime);
      }
    }

    return results;
  }

  String _describeMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final int hours = minutes ~/ 60;

    return '$hours hour${minutes >= 120 ? 's' : ''}';
  }

  int _notificationId(
    String classId, {
    int offset = 0,
  }) {
    return ('class_${classId}_$offset').hashCode &
        0x7fffffff;
  }

  int _taskNotificationId(String taskId) {
    return ('task_$taskId').hashCode &
        0x7fffffff;
  }

  @visibleForTesting
  int notificationIdForTest(String classId) {
    return _notificationId(
      classId,
      offset: 0,
    );
  }
}