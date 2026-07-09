import 'package:pigeon/pigeon.dart';

// Type-safe interface between Dart and the native macOS shell. Regenerate with:
//   dart run pigeon --input pigeons/vimer_api.dart
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/services/vimer_api.g.dart',
    swiftOut: 'macos/Runner/VimerApi.g.swift',
    dartPackageName: 'vimer',
  ),
)

/// One menu-bar item: a timer's remaining/elapsed text in its colour.
class MenuBarTimerData {
  MenuBarTimerData({required this.id, required this.text, required this.color});
  String id;
  String text;
  String color; // 'RRGGBB'
}

/// Dart -> native.
@HostApi()
abstract class VimerHostApi {
  /// Make the frameless window genuinely transparent (undo setAsFrameless).
  void configurePanel();

  /// Show + key the panel without activating a different app inappropriately.
  void showPanel();

  /// Replace the set of menu-bar status items (one per timer).
  void setMenuBarTimers(List<MenuBarTimerData> timers);
}

/// Native -> Dart.
@FlutterApi()
abstract class VimerFlutterApi {
  /// A menu-bar item was clicked.
  void onTimerSelected(String id);

  /// The app resigned active (user clicked another app). Reliable dismiss
  /// signal for a menu-bar app, where window-blur is flaky for an
  /// always-on-top / all-Spaces panel.
  void onResignActive();
}
