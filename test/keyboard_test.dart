import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vimer/src/app.dart';
import 'package:vimer/src/services/prefs.dart';
import 'package:vimer/src/state/providers.dart';
import 'package:vimer/src/state/settings_provider.dart';
import 'package:vimer/src/state/timer_engine.dart';

/// The native plugins aren't present under `flutter test`, so stub their
/// channels; the app only calls them for side effects (tray title, window).
void _stubChannels() {
  const names = [
    'tray_manager',
    'window_manager',
    'hotkey_manager',
    'vimer/window',
    'vimer/menubar',
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
  ];
  for (final name in names) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(Prefs(prefs))]);
}

Future<void> _boot(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const VimerApp()),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// Tear the tree down before disposing the container so no ticker/timer leaks.
/// flutter_animate schedules a zero-duration Timer on mount, so let it fire first.
Future<void> _teardown(WidgetTester tester, ProviderContainer container) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  container.dispose();
}

Future<void> _type(WidgetTester tester, String command) async {
  await tester.enterText(find.byType(TextField), command);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await tester.pump(const Duration(milliseconds: 500)); // list insert animation
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _stubChannels();
  });

  testWidgets('Enter creates a timer from the command field', (tester) async {
    final container = await _container();
    await _boot(tester, container);

    await _type(tester, '5m tea');

    final timers = container.read(timerEngineProvider);
    expect(timers, hasLength(1));
    expect(timers.first.label, 'tea');
    expect(timers.first.isRunning, isTrue);
    expect(timers.first.total, const Duration(minutes: 5));

    await _teardown(tester, container);
  });

  testWidgets('Down selects a timer, Up returns to the input', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '10m focus');

    expect(container.read(selectedTimerIdProvider), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 60));
    final id = container.read(timerEngineProvider).first.id;
    expect(container.read(selectedTimerIdProvider), id);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 60));
    expect(container.read(selectedTimerIdProvider), isNull);

    await _teardown(tester, container);
  });

  testWidgets('Space toggles, P pauses, R resumes the selected timer', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '10m focus');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 60));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(container.read(timerEngineProvider).first.isPaused, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(container.read(timerEngineProvider).first.isRunning, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(container.read(timerEngineProvider).first.isPaused, isTrue);

    await _teardown(tester, container);
  });

  testWidgets('Backspace deletes the selected timer', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '3m');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(timerEngineProvider), isEmpty);
    expect(container.read(selectedTimerIdProvider), isNull);

    await _teardown(tester, container);
  });

  testWidgets('Enter restarts the selected timer', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '10m');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.sendKeyEvent(LogicalKeyboardKey.space); // pause it
    await tester.pump();
    expect(container.read(timerEngineProvider).first.isPaused, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // restart
    await tester.pump();
    expect(container.read(timerEngineProvider).first.isRunning, isTrue);

    await _teardown(tester, container);
  });

  testWidgets('Cmd+, opens Settings and Esc closes it', (tester) async {
    final container = await _container();
    await _boot(tester, container);

    expect(container.read(settingsSheetOpenProvider), isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(settingsSheetOpenProvider), isTrue);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Hide when it loses focus'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(settingsSheetOpenProvider), isFalse);

    await _teardown(tester, container);
  });

  testWidgets('Settings alarm length is adjustable with arrow keys', (tester) async {
    final container = await _container();
    await _boot(tester, container);

    // Open settings; the alarm-length segmented control autofocuses.
    container.read(settingsSheetOpenProvider.notifier).state = true;
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(settingsProvider).alarmDuration, const Duration(seconds: 2));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(container.read(settingsProvider).alarmDuration, const Duration(seconds: 5));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(container.read(settingsProvider).alarmDuration, const Duration(seconds: 10));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(container.read(settingsProvider).alarmDuration, const Duration(seconds: 5));

    await _teardown(tester, container);
  });

  testWidgets('a stopwatch is created as a count-up timer', (tester) async {
    final container = await _container();
    await _boot(tester, container);

    await _type(tester, 'sw deep work #focus');
    final t = container.read(timerEngineProvider).single;
    expect(t.isStopwatch, isTrue);
    expect(t.isRunning, isTrue);
    expect(t.startTime, isNotNull);
    expect(t.total, Duration.zero);
    expect(t.label, 'deep work');
    expect(t.tags, ['focus']);

    await _teardown(tester, container);
  });

  testWidgets('@time creates an alarm with a fire time', (tester) async {
    final container = await _container();
    await _boot(tester, container);

    await _type(tester, 'reminder @11:59pm #life');
    final t = container.read(timerEngineProvider).single;
    expect(t.isAlarm, isTrue);
    expect(t.isStopwatch, isFalse);
    expect(t.fireAt, isNotNull);
    expect(t.endTime, isNotNull);
    expect(t.label, 'reminder');
    expect(t.tags, ['life']);

    await _teardown(tester, container);
  });

  testWidgets('j/k/gg/G navigate the list vim-style', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '5m one');
    await _type(tester, '10m two');
    await _type(tester, '15m three');
    final ids = container.read(timerEngineProvider).map((t) => t.id).toList();
    expect(ids, hasLength(3));

    sel(String? id) => expect(container.read(selectedTimerIdProvider), id);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 60));
    sel(ids[0]);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ); // down
    await tester.pump(const Duration(milliseconds: 40));
    sel(ids[1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyK); // up
    await tester.pump(const Duration(milliseconds: 40));
    sel(ids[0]);

    // G -> last
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 40));
    sel(ids[2]);

    // gg -> first
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pump(const Duration(milliseconds: 40));
    sel(ids[0]);

    await _teardown(tester, container);
  });

  testWidgets('x and dd delete the selected timer', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '5m a');
    await _type(tester, '10m b');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // select first
    await tester.pump(const Duration(milliseconds: 60));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(timerEngineProvider), hasLength(1));

    // dd on the remaining one
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(timerEngineProvider), isEmpty);

    await _teardown(tester, container);
  });

  testWidgets(':clear removes all, :settings and :help open overlays', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '5m a');
    await _type(tester, '10m b');
    expect(container.read(timerEngineProvider), hasLength(2));

    await _type(tester, ':clear');
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(timerEngineProvider), isEmpty);

    await _type(tester, ':settings');
    await tester.pump();
    expect(container.read(settingsSheetOpenProvider), isTrue);
    container.read(settingsSheetOpenProvider.notifier).state = false;
    await tester.pump();

    await _type(tester, ':help');
    await tester.pump();
    expect(container.read(helpOpenProvider), isTrue);

    await _teardown(tester, container);
  });

  testWidgets('help overlay closes with Escape (opened via :help)', (tester) async {
    final container = await _container();
    await _boot(tester, container);

    await _type(tester, ':help');
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(helpOpenProvider), isTrue);
    expect(find.text('Keyboard'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(helpOpenProvider), isFalse, reason: 'Esc should close Help');

    await _teardown(tester, container);
  });

  testWidgets('help overlay closes with Escape (opened while in list mode)', (tester) async {
    final container = await _container();
    await _boot(tester, container);
    await _type(tester, '5m a');

    // Enter list mode, then open help directly (the `?` handler's effect).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 60));
    container.read(helpOpenProvider.notifier).state = true;
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Keyboard'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(helpOpenProvider), isFalse, reason: 'Esc should close Help');

    await _teardown(tester, container);
  });

  testWidgets('typing : shows command suggestions and Tab completes', (tester) async {
    final container = await _container();
    await _boot(tester, container);

    await tester.enterText(find.byType(TextField), ':');
    await tester.pump();
    expect(find.text(':settings'), findsOneWidget);
    expect(find.text(':clear'), findsOneWidget);
    expect(find.text(':help'), findsOneWidget);
    expect(find.text(':quit'), findsOneWidget);

    // Narrow to a single match.
    await tester.enterText(find.byType(TextField), ':se');
    await tester.pump();
    expect(find.text(':settings'), findsOneWidget);
    expect(find.text(':clear'), findsNothing);

    // Tab completes the field to the first match.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, ':settings');

    await _teardown(tester, container);
  });
}
