import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// A keyboard cheatsheet (opened with `?` or `:help`). Esc closes.
class HelpOverlay extends ConsumerStatefulWidget {
  const HelpOverlay({super.key});

  @override
  ConsumerState<HelpOverlay> createState() => _HelpOverlayState();
}

class _HelpOverlayState extends ConsumerState<HelpOverlay> {
  final _focus = FocusNode(debugLabel: 'helpOverlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(panelPinnedProvider.notifier).state = true;
      // Grab keyboard focus so Esc/q reach this overlay's shortcuts instead of
      // the always-focused command field or the list.
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    ref.read(panelPinnedProvider.notifier).state = false;
    ref.read(helpOpenProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.keyQ): _close,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.all(18),
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
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
                        const Text('Keyboard',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Vim.text)),
                        const Spacer(),
                        GlassIconButton(icon: Icons.close_rounded, tooltip: 'Close  ·  Esc', onTap: _close),
                      ],
                    ),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                _Section('TYPE', [
                                  ('type', 'a timer: 25m · @3pm · sw · #tag'),
                                  ('⏎', 'start it'),
                                  ('↓', 'go to the list'),
                                  ('esc', 'clear, or hide'),
                                ]),
                                _Section('SELECT', [
                                  ('j / k', 'move down / up'),
                                  ('gg / G', 'first / last'),
                                  ('i', 'back to the input'),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                _Section('CONTROL', [
                                  ('space', 'pause / resume'),
                                  ('⏎', 'restart'),
                                  ('s', 'stop'),
                                  ('x / dd', 'delete'),
                                ]),
                                _Section('COMMAND', [
                                  (':q', 'quit'),
                                  (':settings', 'settings (⌘,)'),
                                  (':clear', 'remove all'),
                                  (':help ?', 'this'),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Vim.stroke, height: 20),
                    Row(
                      children: const [
                        _Kbd('⌃⌥Z'),
                        SizedBox(width: 9),
                        Flexible(
                          child: Text('summon Vimer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Vim.textDim, fontSize: 12.5)),
                        ),
                        SizedBox(width: 16),
                        _Kbd('esc'),
                        SizedBox(width: 9),
                        Flexible(
                          child: Text('silence alarm',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Vim.textDim, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 160.ms).scaleXY(begin: 0.97, end: 1, duration: 220.ms, curve: Curves.easeOutCubic),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.rows);
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Vim.textFaint, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
          const SizedBox(height: 7),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 62, child: Align(alignment: Alignment.centerLeft, child: _Kbd(r.$1))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Vim.textDim, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Vim.fieldFill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Vim.stroke),
      ),
      child: Text(label,
          style: const TextStyle(color: Vim.text, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}
