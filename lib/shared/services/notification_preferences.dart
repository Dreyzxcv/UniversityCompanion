import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable snapshot of the user's notification settings.
class NotificationPreferences {
  final bool enabled;
  final int classReminderMinutesBefore; // 15, 30, or 60
  final int taskReminderDaysBefore; // 1, 2, or 3

  const NotificationPreferences({
    this.enabled = true,
    this.classReminderMinutesBefore = 60,
    this.taskReminderDaysBefore = 1,
  });

  NotificationPreferences copyWith({
    bool? enabled,
    int? classReminderMinutesBefore,
    int? taskReminderDaysBefore,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      classReminderMinutesBefore:
          classReminderMinutesBefore ?? this.classReminderMinutesBefore,
      taskReminderDaysBefore:
          taskReminderDaysBefore ?? this.taskReminderDaysBefore,
    );
  }
}

/// Holds and persists [NotificationPreferences]. Screens that schedule
/// reminders (ScheduleScreen, TasksScreen) read from this instead of
/// using the old hardcoded 1-hour / 6pm-day-before values.
class NotificationPreferencesController extends ChangeNotifier {
  static const _kEnabled = 'notif_enabled';
  static const _kClassMinutes = 'notif_class_minutes_before';
  static const _kTaskDays = 'notif_task_days_before';

  NotificationPreferences _prefs;
  NotificationPreferencesController._(this._prefs);

  static Future<NotificationPreferencesController> load() async {
    final sp = await SharedPreferences.getInstance();
    return NotificationPreferencesController._(NotificationPreferences(
      enabled: sp.getBool(_kEnabled) ?? true,
      classReminderMinutesBefore: sp.getInt(_kClassMinutes) ?? 60,
      taskReminderDaysBefore: sp.getInt(_kTaskDays) ?? 1,
    ));
  }

  NotificationPreferences get prefs => _prefs;

  Future<void> _persist(NotificationPreferences next) async {
    _prefs = next;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kEnabled, next.enabled);
    await sp.setInt(_kClassMinutes, next.classReminderMinutesBefore);
    await sp.setInt(_kTaskDays, next.taskReminderDaysBefore);
  }

  Future<void> setEnabled(bool v) => _persist(_prefs.copyWith(enabled: v));
  Future<void> setClassMinutesBefore(int v) =>
      _persist(_prefs.copyWith(classReminderMinutesBefore: v));
  Future<void> setTaskDaysBefore(int v) =>
      _persist(_prefs.copyWith(taskReminderDaysBefore: v));
}
