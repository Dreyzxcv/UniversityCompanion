import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls optional visual elements on the Schedule grid, starting with
/// the live "current time" red line indicator.
class ScheduleDisplayController extends ChangeNotifier {
  static const _kShowTimeIndicator = 'schedule_show_time_indicator';

  bool _showTimeIndicator;
  ScheduleDisplayController._(this._showTimeIndicator);

  static Future<ScheduleDisplayController> load() async {
    final sp = await SharedPreferences.getInstance();
    return ScheduleDisplayController._(
      sp.getBool(_kShowTimeIndicator) ?? true,
    );
  }

  bool get showTimeIndicator => _showTimeIndicator;

  Future<void> setShowTimeIndicator(bool value) async {
    if (_showTimeIndicator == value) return;
    _showTimeIndicator = value;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kShowTimeIndicator, value);
  }
}