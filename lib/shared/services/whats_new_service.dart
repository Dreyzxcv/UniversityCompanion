import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the "What's New" dialog has been shown for the
/// current app version. Call [shouldShow] on startup; call [markSeen]
/// after the dialog is dismissed.
class WhatsNewService {
  static const _kPrefKey = 'whats_new_last_seen_version';

  /// Returns true if the dialog hasn't been shown yet for this build version.
  static Future<bool> shouldShow() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = '${info.version}+${info.buildNumber}';
    final sp = await SharedPreferences.getInstance();
    final lastSeen = sp.getString(_kPrefKey);
    return lastSeen != currentVersion;
  }

  /// Call this after the dialog is dismissed so it won't show again
  /// until the next version.
  static Future<void> markSeen() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = '${info.version}+${info.buildNumber}';
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPrefKey, currentVersion);
  }

  /// For debugging: resets the seen flag so the dialog will show again
  /// on next launch (useful while building the feature).
  static Future<void> resetForTesting() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kPrefKey);
  }
}