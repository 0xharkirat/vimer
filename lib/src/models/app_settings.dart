import 'dart:convert';

/// Immutable user settings, persisted as a JSON blob in shared_preferences.
class AppSettings {
  const AppSettings({
    this.alarmDuration = const Duration(seconds: 2),
    this.soundPath,
    this.soundName = defaultSoundName,
    this.volume = 0.9,
    this.summonHotkeyEnabled = true,
    this.autoHideOnBlur = true,
  });

  static const String defaultSoundName = 'Vimer Chime';

  /// How long the alarm keeps playing when a timer finishes.
  final Duration alarmDuration;

  /// Absolute path to a custom sound copied into the app container, or `null`
  /// to use the bundled chime.
  final String? soundPath;
  final String soundName;

  /// Playback volume, 0.0 - 1.0.
  final double volume;

  /// When true, a global Control+Option+Z summons the panel from anywhere.
  final bool summonHotkeyEnabled;

  /// When true, clicking away dismisses the panel (Spotlight behaviour).
  final bool autoHideOnBlur;

  bool get usesCustomSound => soundPath != null;

  AppSettings copyWith({
    Duration? alarmDuration,
    Object? soundPath = _noChange,
    String? soundName,
    double? volume,
    bool? summonHotkeyEnabled,
    bool? autoHideOnBlur,
  }) {
    return AppSettings(
      alarmDuration: alarmDuration ?? this.alarmDuration,
      soundPath: identical(soundPath, _noChange)
          ? this.soundPath
          : soundPath as String?,
      soundName: soundName ?? this.soundName,
      volume: volume ?? this.volume,
      summonHotkeyEnabled: summonHotkeyEnabled ?? this.summonHotkeyEnabled,
      autoHideOnBlur: autoHideOnBlur ?? this.autoHideOnBlur,
    );
  }

  Map<String, Object?> toJson() => {
        'alarmMs': alarmDuration.inMilliseconds,
        'soundPath': soundPath,
        'soundName': soundName,
        'volume': volume,
        'summon': summonHotkeyEnabled,
        'autoHide': autoHideOnBlur,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        alarmDuration:
            Duration(milliseconds: (json['alarmMs'] as num?)?.toInt() ?? 2000),
        soundPath: json['soundPath'] as String?,
        soundName: (json['soundName'] as String?) ?? defaultSoundName,
        volume: (json['volume'] as num?)?.toDouble() ?? 0.9,
        summonHotkeyEnabled: (json['summon'] as bool?) ?? true,
        autoHideOnBlur: (json['autoHide'] as bool?) ?? true,
      );

  String encode() => jsonEncode(toJson());

  static AppSettings decode(String raw) =>
      AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);

  /// Sentinel so [copyWith] can distinguish "leave soundPath" from "set null".
  static const Object _noChange = Object();
}
