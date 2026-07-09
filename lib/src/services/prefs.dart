import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Small typed facade over shared_preferences.
class Prefs {
  Prefs(this._sp);
  final SharedPreferences _sp;

  static const _kSettings = 'vimer.settings.v1';

  AppSettings loadSettings() {
    final raw = _sp.getString(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.decode(raw);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) =>
      _sp.setString(_kSettings, settings.encode());
}
