import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import 'providers.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(prefsProvider).loadSettings();

  Future<void> _apply(AppSettings next) async {
    state = next;
    await ref.read(prefsProvider).saveSettings(next);
    await ref.read(alarmServiceProvider).setVolume(next.volume);
    final native = ref.read(nativeServiceProvider);
    native.autoHideOnBlur = next.autoHideOnBlur;
    if (next.summonHotkeyEnabled) {
      await native.enableSummonHotkey();
    } else {
      await native.disableSummonHotkey();
    }
  }

  void setAlarmDuration(Duration d) => _apply(state.copyWith(alarmDuration: d));
  void setVolume(double v) => _apply(state.copyWith(volume: v));
  void setSummonHotkey(bool enabled) =>
      _apply(state.copyWith(summonHotkeyEnabled: enabled));
  void setAutoHideOnBlur(bool enabled) =>
      _apply(state.copyWith(autoHideOnBlur: enabled));
  void setCustomSound(String path, String name) =>
      _apply(state.copyWith(soundPath: path, soundName: name));
  void resetSound() => _apply(
        state.copyWith(soundPath: null, soundName: AppSettings.defaultSoundName),
      );
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
