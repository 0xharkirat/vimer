/// Parses a free-form command into a timer spec: a countdown, a clock-time
/// alarm (`@12pm`), or a stopwatch, plus any `#tags` and a label.
///
/// Examples:
///   * `25m deep work #focus`     -> 25-minute countdown, label "deep work"
///   * `1h30m` / `90s` / `25:00`  -> countdowns
///   * `@3:30pm standup #team`    -> alarm at 3:30 PM
///   * `@noon lunch`              -> alarm at 12:00 PM
///   * `stopwatch #coding` / `sw` -> count-up stopwatch
enum CommandKind { countdown, alarm, stopwatch }

class ParsedCommand {
  const ParsedCommand({
    required this.kind,
    this.duration,
    this.fireAt,
    this.label,
    this.tags = const [],
  });

  final CommandKind kind;

  /// Time until it fires (countdown/alarm). Null for a stopwatch.
  final Duration? duration;

  /// Absolute clock time an alarm fires at (for display). Null otherwise.
  final DateTime? fireAt;

  final String? label;
  final List<String> tags;

  @override
  bool operator ==(Object other) =>
      other is ParsedCommand &&
      other.kind == kind &&
      other.duration == duration &&
      other.fireAt == fireAt &&
      other.label == label &&
      _listEq(other.tags, tags);

  @override
  int get hashCode => Object.hash(kind, duration, fireAt, label, Object.hashAll(tags));

  @override
  String toString() => 'ParsedCommand($kind, $duration, at:$fireAt, "$label", $tags)';
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final RegExp _tagToken = RegExp(r'#([A-Za-z0-9_\-]+)');
final RegExp _atToken = RegExp(r'@([0-9a-zA-Z:]+)');
final RegExp _stopwatchToken = RegExp(r'\b(stopwatch|sw)\b', caseSensitive: false);
final RegExp _clockToken = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$', caseSensitive: false);

final RegExp _unitToken = RegExp(
  r'(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)',
  caseSensitive: false,
);
final RegExp _colonToken = RegExp(r'(\d{1,3}(?::\d{1,2}){1,2})');
final RegExp _leadingNumber = RegExp(r'^(\d+(?:\.\d+)?)(?:\s+(.*))?$');
final RegExp _whitespace = RegExp(r'\s+');

const Duration _maxDuration = Duration(hours: 99, minutes: 59, seconds: 59);

ParsedCommand? parseCommand(String input, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  var text = input.trim();
  if (text.isEmpty) return null;

  // 1) #tags (extracted from anywhere).
  final tags = _tagToken.allMatches(text).map((m) => m.group(1)!.toLowerCase()).toList();
  text = text.replaceAll(_tagToken, ' ');

  // 2) @clock-time alarm.
  final at = _atToken.firstMatch(text);
  if (at != null) {
    final target = _clockTime(at.group(1)!, clock);
    if (target != null) {
      return ParsedCommand(
        kind: CommandKind.alarm,
        duration: target.difference(clock),
        fireAt: target,
        label: _cleanLabel(text.replaceRange(at.start, at.end, ' ')),
        tags: tags,
      );
    }
  }

  // 3) Stopwatch.
  if (_stopwatchToken.hasMatch(text)) {
    return ParsedCommand(
      kind: CommandKind.stopwatch,
      label: _cleanLabel(text.replaceAll(_stopwatchToken, ' ')),
      tags: tags,
    );
  }

  // 4) Countdown duration.
  final dl = _durationAndLabel(text);
  if (dl != null) {
    return ParsedCommand(
      kind: CommandKind.countdown,
      duration: _clamp(dl.duration),
      label: dl.label,
      tags: tags,
    );
  }

  return null;
}

/// The next occurrence of `hh:mm` in the given 12/24h string, or null.
DateTime? _clockTime(String raw, DateTime now) {
  final s = raw.trim().toLowerCase();
  if (s == 'noon') return _nextAt(now, 12, 0);
  if (s == 'midnight') return _nextAt(now, 0, 0);
  final m = _clockToken.firstMatch(s);
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2) ?? '0');
  final ampm = m.group(3)?.toLowerCase();
  if (minute > 59) return null;
  if (ampm != null) {
    if (hour < 1 || hour > 12) return null;
    if (ampm == 'pm' && hour != 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
  } else if (hour > 23) {
    return null;
  }
  return _nextAt(now, hour, minute);
}

DateTime _nextAt(DateTime now, int hour, int minute) {
  var t = DateTime(now.year, now.month, now.day, hour, minute);
  if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
  return t;
}

class _DurationLabel {
  const _DurationLabel(this.duration, this.label);
  final Duration duration;
  final String? label;
}

_DurationLabel? _durationAndLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final unitMatches = _unitToken.allMatches(text).toList();
  if (unitMatches.isNotEmpty) {
    final duration = _durationFromUnits(unitMatches);
    if (duration == null) return null;
    return _DurationLabel(duration, _cleanLabel(text.replaceAll(_unitToken, ' ')));
  }

  final colon = _colonToken.firstMatch(text);
  if (colon != null) {
    final duration = _durationFromColon(colon.group(1)!);
    if (duration == null) return null;
    return _DurationLabel(duration, _cleanLabel(text.replaceRange(colon.start, colon.end, ' ')));
  }

  final bare = _leadingNumber.firstMatch(text);
  if (bare != null) {
    final value = double.parse(bare.group(1)!);
    if (value <= 0) return null;
    return _DurationLabel(
      Duration(milliseconds: (value * 60 * 1000).round()),
      _cleanLabel(bare.group(2) ?? ''),
    );
  }

  return null;
}

Duration? _durationFromUnits(Iterable<RegExpMatch> matches) {
  var seconds = 0.0;
  for (final m in matches) {
    final value = double.parse(m.group(1)!);
    final unit = m.group(2)!.toLowerCase();
    if (unit.startsWith('h')) {
      seconds += value * 3600;
    } else if (unit.startsWith('m')) {
      seconds += value * 60;
    } else {
      seconds += value;
    }
  }
  if (seconds <= 0) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

Duration? _durationFromColon(String token) {
  final parts = token.split(':').map(int.parse).toList();
  Duration total;
  if (parts.length == 2) {
    if (parts[1] >= 60) return null;
    total = Duration(minutes: parts[0], seconds: parts[1]);
  } else if (parts.length == 3) {
    if (parts[1] >= 60 || parts[2] >= 60) return null;
    total = Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
  } else {
    return null;
  }
  return total.inMilliseconds > 0 ? total : null;
}

String? _cleanLabel(String value) {
  final label = value.replaceAll(_whitespace, ' ').trim();
  return label.isEmpty ? null : label;
}

Duration _clamp(Duration d) => d > _maxDuration ? _maxDuration : d;
