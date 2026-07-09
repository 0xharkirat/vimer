enum TimerStatus { running, paused, ringing, done }

enum TimerKind { countdown, stopwatch }

/// A single timer. A countdown (optionally an alarm at a wall-clock [fireAt])
/// stores an absolute [endTime]; a stopwatch counts up from [startTime].
class TimerModel {
  const TimerModel({
    required this.id,
    required this.createdAt,
    required this.status,
    this.kind = TimerKind.countdown,
    this.total = Duration.zero,
    this.colorIndex = 0,
    this.label,
    this.tags = const [],
    this.isAlarm = false,
    this.fireAt,
    this.endTime,
    this.pausedRemaining,
    this.startTime,
    this.pausedElapsed,
  });

  final String id;
  final String? label;
  final List<String> tags;
  final TimerKind kind;
  final Duration total;
  final DateTime createdAt;
  final TimerStatus status;
  final int colorIndex;

  /// Alarm = a countdown created for a specific clock time.
  final bool isAlarm;
  final DateTime? fireAt;

  // Countdown state.
  final DateTime? endTime;
  final Duration? pausedRemaining;

  // Stopwatch state.
  final DateTime? startTime;
  final Duration? pausedElapsed;

  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isRinging => status == TimerStatus.ringing;
  bool get isDone => status == TimerStatus.done;
  bool get isFinished => isRinging || isDone;
  bool get isStopwatch => kind == TimerKind.stopwatch;

  Duration remaining(DateTime now) {
    if (isStopwatch) return Duration.zero;
    switch (status) {
      case TimerStatus.running:
        final r = endTime!.difference(now);
        return r.isNegative ? Duration.zero : r;
      case TimerStatus.paused:
        return pausedRemaining ?? Duration.zero;
      case TimerStatus.ringing:
      case TimerStatus.done:
        return Duration.zero;
    }
  }

  Duration elapsed(DateTime now) {
    if (isStopwatch) {
      return status == TimerStatus.running
          ? now.difference(startTime!)
          : (pausedElapsed ?? Duration.zero);
    }
    return total - remaining(now);
  }

  /// Fraction of time remaining, 1.0 -> 0.0. Always 1.0 for a stopwatch.
  double remainingFraction(DateTime now) {
    if (isStopwatch) return 1;
    final totalMs = total.inMilliseconds;
    if (totalMs <= 0) return 0;
    if (isFinished) return 0;
    return (remaining(now).inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  TimerModel copyWith({
    TimerStatus? status,
    String? label,
    DateTime? endTime,
    Duration? pausedRemaining,
    DateTime? startTime,
    Duration? pausedElapsed,
  }) {
    return TimerModel(
      id: id,
      kind: kind,
      total: total,
      createdAt: createdAt,
      colorIndex: colorIndex,
      tags: tags,
      isAlarm: isAlarm,
      fireAt: fireAt,
      status: status ?? this.status,
      label: label ?? this.label,
      endTime: endTime ?? this.endTime,
      pausedRemaining: pausedRemaining ?? this.pausedRemaining,
      startTime: startTime ?? this.startTime,
      pausedElapsed: pausedElapsed ?? this.pausedElapsed,
    );
  }
}
