import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/services/prefs.dart';
import 'src/state/providers.dart';
import 'src/state/settings_provider.dart';
import 'src/state/timer_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll(); // clear any stale system hotkeys

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(Prefs(prefs))],
  );

  // Bring the native shell up (tray + window listeners) before showing.
  final native = container.read(nativeServiceProvider);
  await native.init();

  const options = WindowOptions(
    size: Size(540, 600),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setVisibleOnAllWorkspaces(true, visibleOnFullScreen: true);
    await windowManager.setResizable(false);
    await native.configurePanel();         // real transparency (after setAsFrameless)
  });

  container.read(timerEngineProvider); // wire native callbacks
  final settings = container.read(settingsProvider);
  native.autoHideOnBlur = settings.autoHideOnBlur;
  await container.read(alarmServiceProvider).setVolume(settings.volume);
  if (settings.summonHotkeyEnabled) await native.enableSummonHotkey();

  runApp(
    UncontrolledProviderScope(container: container, child: const VimerApp()),
  );

  // Reveal only after the first frame is painted, so the window never flashes
  // an empty or default-sized frame on launch (the window is visibleAtLaunch=NO).
  WidgetsBinding.instance.addPostFrameCallback((_) => native.showPanel());
}
