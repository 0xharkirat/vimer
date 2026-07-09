import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../state/providers.dart';
import '../state/settings_provider.dart';
import '../theme.dart';
import 'widgets.dart';

/// Slide-up settings sheet. Fully keyboard-navigable: it traps focus, autofocuses
/// the first control, Tab cycles the controls, and Esc closes it.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(panelPinnedProvider.notifier).state = true;
    });
  }

  void _close() {
    ref.read(panelPinnedProvider.notifier).state = false;
    ref.read(settingsSheetOpenProvider.notifier).state = false;
  }

  Future<void> _pickSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'aiff', 'aif', 'm4a', 'caf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final soundsDir = Directory(p.join(dir.path, 'sounds'));
      if (!soundsDir.existsSync()) soundsDir.createSync(recursive: true);
      final dest = p.join(soundsDir.path, p.basename(path));
      await File(path).copy(dest);
      ref.read(settingsProvider.notifier).setCustomSound(dest, p.basename(path));
    } catch (_) {
      ref.read(settingsProvider.notifier).setCustomSound(path, p.basename(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final alarmSecs = settings.alarmDuration.inSeconds;

    return FocusScope(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _close,
        },
        child: GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // swallow taps inside the sheet
              child: FocusTraversalGroup(
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Vim.cardTop, Vim.cardBottom],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Vim.strokeStrong),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Settings',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Vim.text)),
                          const Spacer(),
                          GlassIconButton(icon: Icons.close_rounded, tooltip: 'Close  ·  Esc', onTap: _close),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _label('ALARM LENGTH'),
                      const SizedBox(height: 8),
                      VimSegmented<int>(
                        autofocus: true,
                        value: alarmSecs,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .setAlarmDuration(Duration(seconds: v)),
                        options: const [
                          (value: 2, label: '2s'),
                          (value: 5, label: '5s'),
                          (value: 10, label: '10s'),
                          (value: 30, label: '30s'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _label('SOUND'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: Vim.fieldFill,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: Vim.stroke),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    settings.usesCustomSound
                                        ? Icons.music_note_rounded
                                        : Icons.notifications_rounded,
                                    size: 16,
                                    color: Vim.mint,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(settings.soundName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Vim.text, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GlassIconButton(
                            icon: Icons.play_arrow_rounded,
                            tooltip: 'Preview',
                            color: Vim.mint,
                            onTap: () => ref.read(alarmServiceProvider).preview(settings),
                          ),
                          GlassIconButton(
                            icon: Icons.folder_open_rounded,
                            tooltip: 'Choose file',
                            onTap: _pickSound,
                          ),
                          if (settings.usesCustomSound)
                            GlassIconButton(
                              icon: Icons.restart_alt_rounded,
                              tooltip: 'Reset to default',
                              onTap: () => ref.read(settingsProvider.notifier).resetSound(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _label('VOLUME'),
                      Row(
                        children: [
                          const Icon(Icons.volume_down_rounded, size: 18, color: Vim.textDim),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: 1,
                              value: settings.volume,
                              onChanged: (v) => ref.read(settingsProvider.notifier).setVolume(v),
                            ),
                          ),
                          const Icon(Icons.volume_up_rounded, size: 18, color: Vim.textDim),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _label('GLOBAL SHORTCUT'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Summon Vimer',
                                    style: TextStyle(color: Vim.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text('Control + Option + Z, from any app',
                                    style: TextStyle(color: Vim.textFaint, fontSize: 11.5)),
                              ],
                            ),
                          ),
                          Switch(
                            value: settings.summonHotkeyEnabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Vim.mint,
                            onChanged: (v) => ref.read(settingsProvider.notifier).setSummonHotkey(v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _label('PANEL'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hide when it loses focus',
                                    style: TextStyle(color: Vim.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text('Click away to dismiss, like Spotlight',
                                    style: TextStyle(color: Vim.textFaint, fontSize: 11.5)),
                              ],
                            ),
                          ),
                          Switch(
                            value: settings.autoHideOnBlur,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Vim.mint,
                            onChanged: (v) => ref.read(settingsProvider.notifier).setAutoHideOnBlur(v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Vim.stroke, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Vimer 1.0', style: TextStyle(color: Vim.textFaint, fontSize: 11.5)),
                          const Spacer(),
                          _QuitButton(onTap: () => ref.read(nativeServiceProvider).onQuit?.call()),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.12, end: 0, duration: 260.ms, curve: Curves.easeOutCubic),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Vim.textFaint, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      );
}

class _QuitButton extends StatefulWidget {
  const _QuitButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_QuitButton> createState() => _QuitButtonState();
}

class _QuitButtonState extends State<_QuitButton> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final lit = _hover || _focused;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: lit ? const Color(0x33FF5C5C) : Vim.fieldFill,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: lit ? const Color(0x66FF5C5C) : Vim.stroke),
          ),
          child: Text('Quit Vimer',
              style: TextStyle(
                  color: lit ? const Color(0xFFFF8A8A) : Vim.textDim,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
