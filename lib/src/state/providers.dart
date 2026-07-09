import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/alarm_service.dart';
import '../services/native_service.dart';
import '../services/prefs.dart';

/// Overridden in `main()` once SharedPreferences has loaded.
final prefsProvider = Provider<Prefs>(
  (ref) => throw StateError('prefsProvider must be overridden in main()'),
);

final alarmServiceProvider = Provider<AlarmService>((ref) {
  final service = AlarmService();
  ref.onDispose(service.dispose);
  return service;
});

final nativeServiceProvider = Provider<NativeService>((ref) {
  final service = NativeService();
  ref.onDispose(service.dispose);
  return service;
});

/// Keeps the panel open despite losing focus (Settings sheet or file picker).
final panelPinnedProvider = StateProvider<bool>((ref) => false);

/// Whether the Settings sheet is visible.
final settingsSheetOpenProvider = StateProvider<bool>((ref) => false);

/// The timer currently selected for keyboard control, or null when the command
/// field is the active input.
final selectedTimerIdProvider = StateProvider<String?>((ref) => null);

/// Whether the keyboard cheatsheet overlay is visible.
final helpOpenProvider = StateProvider<bool>((ref) => false);

/// Text to push into the command field (e.g. ':' to start a command),
/// consumed once by the command bar.
final pendingInputProvider = StateProvider<String?>((ref) => null);
