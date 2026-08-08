import 'package:flutter/foundation.dart';

/// App-wide preference for whether times are shown in 24-hour ("military")
/// or 12-hour (AM/PM) format. In-memory only for now — add a persistence
/// layer (e.g. shared_preferences) later if this should survive app restarts.
class TimeFormatController extends ChangeNotifier {
  bool _is24Hour = true; // matches how times are already stored ("HH:mm")

  bool get is24Hour => _is24Hour;

  void setIs24Hour(bool value) {
    if (_is24Hour == value) return;
    _is24Hour = value;
    notifyListeners();
  }

  void toggle() => setIs24Hour(!_is24Hour);
}