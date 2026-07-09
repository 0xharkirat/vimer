import 'package:audioplayers/audioplayers.dart';

import '../models/app_settings.dart';

const String _kAssetChime = 'sounds/vimer_chime.wav';

/// Thin wrapper over audioplayers. Coordination (when to start/stop, for how
/// long) lives in [TimerEngine]; this just plays sound.
class AlarmService {
  final AudioPlayer _alarm = AudioPlayer(playerId: 'vimer.alarm');
  final AudioPlayer _preview = AudioPlayer(playerId: 'vimer.preview');
  double _volume = 0.9;

  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _alarm.setVolume(volume);
  }

  Source _sourceFor(AppSettings s) => s.usesCustomSound
      ? DeviceFileSource(s.soundPath!)
      : AssetSource(_kAssetChime);

  /// Start (or restart) the looping alarm. Safe to call while already ringing.
  Future<void> startLoop(AppSettings settings) async {
    await _alarm.stop();
    await _alarm.setReleaseMode(ReleaseMode.loop);
    await _alarm.setVolume(_volume);
    await _alarm.play(_sourceFor(settings), volume: _volume);
  }

  Future<void> stop() => _alarm.stop();

  /// Play the current sound once, for previewing in Settings.
  Future<void> preview(AppSettings settings) async {
    await _preview.stop();
    await _preview.setReleaseMode(ReleaseMode.stop);
    await _preview.play(_sourceFor(settings), volume: _volume);
  }

  Future<void> dispose() async {
    await _alarm.dispose();
    await _preview.dispose();
  }
}
