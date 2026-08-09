import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preference for whether times are shown in 24-hour ("military")
/// or 12-hour (AM/PM) format.
class TimeFormatController extends ChangeNotifier {
  static const _key = 'is_24_hour';

  bool _is24Hour;
  TimeFormatController._(this._is24Hour);

  static Future<TimeFormatController> load() async {
    final sp = await SharedPreferences.getInstance();
    return TimeFormatController._(sp.getBool(_key) ?? true);
  }

  bool get is24Hour => _is24Hour;

  Future<void> setIs24Hour(bool value) async {
    if (_is24Hour == value) return;
    _is24Hour = value;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, value);
  }

  void toggle() => setIs24Hour(!_is24Hour);
}