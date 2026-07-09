import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_model.dart';
import '../services/duration_parser.dart';
import '../theme.dart';
import '../util/format.dart';
import 'providers.dart';
import 'settings_provider.dart';

/// The heart of the app: holds every timer, ticks them down, and orchestrates
/// the alarm + menu-bar title. UI cards read individual timers reactively;
/// this only rebuilds the list when membership or status actually changes.
class TimerEngine extends Notifier<List<TimerModel>> {
  Timer? _ticker;
  final Set<String> _ringing = {};
  final Map<String, Timer> _ringStopTimers = {};
  int _idSeq = 0;
  int _colorSeq = 0;

  @override
  List<TimerModel> build() {
    final native = ref.read(nativeServiceProvider);
    native.onEscape = stopAllRinging;
    native.onSummon = native.reveal;
    native.onToggleWindow = native.toggle;
    native.onOpenSettings = () {
      native.reveal();
      ref.read(settingsSheetOpenProvider.notifier).state = true;
    };
    native.onQuit = _quit;
    native.onSelectTimer = (id) {
      native.reveal();
      ref.read(selectedTimerIdProvider.notifier).state = id;
    };
    native.stayOpenOnBlur =
        () => _ringing.isNotEmpty || ref.read(panelPinnedProvider);

    ref.onDispose(() {
      _ticker?.cancel();
      for (final t in _ringStopTimers.values) {
        t.cancel();
      }
    });
    return const [];
  }

  /// Parse and start a timer. Returns the created timer, or null if the command
  /// didn't contain a valid duration.
  TimerModel? add(String rawCommand) {
    final parsed = parseCommand(rawCommand);
    if (parsed == null) return null;
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}-${_idSeq++}';
    final colorIndex = _colorSeq++;

    final TimerModel timer;
    if (parsed.kind == CommandKind.stopwatch) {
      timer = TimerModel(
        id: id,
        kind: TimerKind.stopwatch,
        createdAt: now,
        colorIndex: colorIndex,
        status: TimerStatus.running,
        startTime: now,
        label: parsed.label,
        tags: parsed.tags,
      );
    } else {
      final duration = parsed.duration!;
      timer = TimerModel(
        id: id,
        total: duration,
        createdAt: now,
        colorIndex: colorIndex,
        status: TimerStatus.running,
        endTime: now.add(duration),
        label: parsed.label,
        tags: parsed.tags,
        isAlarm: parsed.kind == CommandKind.alarm,
        fireAt: parsed.fireAt,
      );
    }
    state = [...state, timer];
    _ensureTicker();
    _updateMenuBar(now);
    return timer;
  }

  // --- controls ---
  void pause(String id) {
    final now = DateTime.now();
    _mutate(id, (t) {
      if (!t.isRunning) return t;
      if (t.isStopwatch) {
        return t.copyWith(status: TimerStatus.paused, pausedElapsed: now.difference(t.startTime!));
      }
      final rem = t.endTime!.difference(now);
      return t.copyWith(
        status: TimerStatus.paused,
        pausedRemaining: rem.isNegative ? Duration.zero : rem,
      );
    });
    _updateMenuBar(now);
  }

  void resume(String id) {
    final now = DateTime.now();
    _mutate(id, (t) {
      if (!t.isPaused) return t;
      if (t.isStopwatch) {
        return t.copyWith(
          status: TimerStatus.running,
          startTime: now.subtract(t.pausedElapsed ?? Duration.zero),
        );
      }
      return t.copyWith(
        status: TimerStatus.running,
        endTime: now.add(t.pausedRemaining ?? Duration.zero),
      );
    });
    _ensureTicker();
    _updateMenuBar(now);
  }

  void toggle(String id) {
    final t = _byId(id);
    if (t == null) return;
    if (t.isRunning) {
      pause(id);
    } else if (t.isPaused) {
      resume(id);
    }
  }

  void restart(String id) {
    if (_ringing.contains(id)) _endRing(id, markDone: false);
    final now = DateTime.now();
    _mutate(id, (t) {
      if (t.isStopwatch) {
        return t.copyWith(status: TimerStatus.running, startTime: now);
      }
      return t.copyWith(status: TimerStatus.running, endTime: now.add(t.total));
    });
    _ensureTicker();
    _updateMenuBar(now);
  }

  void dismiss(String id) {
    if (_ringing.contains(id)) _endRing(id, markDone: false);
    state = state.where((t) => t.id != id).toList();
    _updateMenuBar(DateTime.now());
    _maybeStopTicker();
  }

  // --- ring lifecycle ---
  void _startRing(String id) {
    final settings = ref.read(settingsProvider);
    final native = ref.read(nativeServiceProvider);
    final firstRing = _ringing.isEmpty;
    _ringing.add(id);
    ref.read(alarmServiceProvider).startLoop(settings);
    if (firstRing) native.registerEscape();
    native.reveal();
    _ringStopTimers[id]?.cancel();
    _ringStopTimers[id] =
        Timer(settings.alarmDuration, () => _endRing(id, markDone: true));
  }

  void _endRing(String id, {required bool markDone}) {
    _ringStopTimers.remove(id)?.cancel();
    final wasRinging = _ringing.remove(id);
    if (_ringing.isEmpty) {
      ref.read(alarmServiceProvider).stop();
      ref.read(nativeServiceProvider).unregisterEscape();
    }
    if (wasRinging && markDone) {
      _setStatus(id, TimerStatus.done);
      _scheduleAutoDismiss(id);
    }
  }

  /// Global Escape handler: silence every ringing alarm at once.
  void stopAllRinging() {
    if (_ringing.isEmpty) return;
    final ids = _ringing.toList();
    for (final id in ids) {
      _ringStopTimers.remove(id)?.cancel();
      _ringing.remove(id);
    }
    ref.read(alarmServiceProvider).stop();
    ref.read(nativeServiceProvider).unregisterEscape();
    for (final id in ids) {
      _setStatus(id, TimerStatus.done);
      _scheduleAutoDismiss(id);
    }
  }

  /// Silence one ringing alarm without removing the timer (marks it done).
  void silence(String id) => _endRing(id, markDone: true);

  /// Remove every timer (the `:clear` command).
  void clearAll() {
    for (final id in _ringing.toList()) {
      _ringStopTimers.remove(id)?.cancel();
    }
    _ringing.clear();
    ref.read(alarmServiceProvider).stop();
    ref.read(nativeServiceProvider).unregisterEscape();
    state = const [];
    ref.read(selectedTimerIdProvider.notifier).state = null;
    _updateMenuBar(DateTime.now());
    _maybeStopTicker();
  }

  void _scheduleAutoDismiss(String id) {
    Timer(const Duration(seconds: 6), () {
      final t = _byId(id);
      if (t != null && t.isDone) dismiss(id);
    });
  }

  // --- ticking ---
  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    var changed = false;
    final next = <TimerModel>[];
    for (final t in state) {
      // Stopwatches never complete; only countdown/alarm timers ring.
      if (t.kind == TimerKind.countdown && t.isRunning && t.endTime != null && !t.endTime!.isAfter(now)) {
        next.add(t.copyWith(status: TimerStatus.ringing));
        changed = true;
      } else {
        next.add(t);
      }
    }
    if (changed) {
      state = next;
      for (final t in next) {
        if (t.isRinging && !_ringing.contains(t.id)) _startRing(t.id);
      }
    }
    _updateMenuBar(now);
    _maybeStopTicker();
  }

  void _maybeStopTicker() {
    if (!state.any((t) => t.isRunning) && _ringing.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _updateMenuBar(DateTime now) {
    final native = ref.read(nativeServiceProvider);
    // One menu-bar item per timer (running, paused, or ringing), in its colour.
    final visible = state.where((t) => !t.isDone).toList();
    final items = <Map<String, Object>>[
      for (final t in visible)
        {
          'id': t.id,
          'text': t.isStopwatch
              ? formatTray(t.elapsed(now))
              : (t.isRinging ? '0:00' : formatTray(t.remaining(now))),
          'color': _hexColor(t.isRinging ? Vim.ring : Vim.timerColor(t.colorIndex)),
        },
    ];
    native.setMenuBarTimers(items);
  }

  static String _hexColor(Color c) {
    int ch(double v) => (v * 255).round().clamp(0, 255);
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(ch(c.r))}${h(ch(c.g))}${h(ch(c.b))}';
  }

  // --- helpers ---
  TimerModel? _byId(String id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _mutate(String id, TimerModel Function(TimerModel) transform) {
    state = [for (final t in state) if (t.id == id) transform(t) else t];
  }

  void _setStatus(String id, TimerStatus status) =>
      _mutate(id, (t) => t.copyWith(status: status));

  Future<void> _quit() async {
    _ticker?.cancel();
    for (final t in _ringStopTimers.values) {
      t.cancel();
    }
    await ref.read(alarmServiceProvider).stop();
    exit(0);
  }
}

final timerEngineProvider =
    NotifierProvider<TimerEngine, List<TimerModel>>(TimerEngine.new);

/// Convenience: watch a single timer by id (null once it's removed).
final timerByIdProvider = Provider.family<TimerModel?, String>((ref, id) {
  final list = ref.watch(timerEngineProvider);
  for (final t in list) {
    if (t.id == id) return t;
  }
  return null;
});
