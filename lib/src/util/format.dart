String _two(int n) => n.toString().padLeft(2, '0');

/// `mm:ss`, or `h:mm:ss` once there is at least one hour.
String formatClock(Duration d) {
  final t = d.isNegative ? Duration.zero : d;
  final h = t.inHours;
  final m = t.inMinutes.remainder(60);
  final s = t.inSeconds.remainder(60);
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

/// Stopwatch readout: `mm:ss.cs` (centiseconds), or `h:mm:ss` past an hour
/// where hundredths would just be noise.
String formatStopwatch(Duration d) {
  final t = d.isNegative ? Duration.zero : d;
  final h = t.inHours;
  final m = t.inMinutes.remainder(60);
  final s = t.inSeconds.remainder(60);
  if (h > 0) return '$h:${_two(m)}:${_two(s)}';
  final cs = (t.inMilliseconds ~/ 10).remainder(100);
  return '${_two(m)}:${_two(s)}.${_two(cs)}';
}

/// Compact form for the menu-bar title (no leading zero on the lead unit).
String formatTray(Duration d) {
  final t = d.isNegative ? Duration.zero : d;
  final h = t.inHours;
  final m = t.inMinutes.remainder(60);
  final s = t.inSeconds.remainder(60);
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

/// Human phrase for previews, e.g. `1h 30m`, `25m`, `45s`.
String humanizeDuration(Duration d) {
  final parts = <String>[];
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}m');
  if (s > 0) parts.add('${s}s');
  return parts.isEmpty ? '0s' : parts.join(' ');
}

/// Local wall-clock time a timer would end, e.g. `3:41 PM`.
String formatEndTime(DateTime end) {
  final h12 = end.hour % 12 == 0 ? 12 : end.hour % 12;
  final ampm = end.hour < 12 ? 'AM' : 'PM';
  return '$h12:${_two(end.minute)} $ampm';
}
