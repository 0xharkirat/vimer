import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../state/providers.dart';
import '../state/timer_engine.dart';
import '../theme.dart';
import 'command_bar.dart';
import 'help_overlay.dart';
import 'settings_sheet.dart';
import 'timer_list.dart';
import 'widgets.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // ⌘, opens/closes Settings, the macOS convention.
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () {
          final open = ref.read(settingsSheetOpenProvider);
          ref.read(settingsSheetOpenProvider.notifier).state = !open;
        },
      },
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 16), child: _Panel()),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kPanelRadius),
        boxShadow: [
          // A single soft, pulled-in shadow reads as a gentle lift rather than
          // a hard outline around the panel.
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 60,
              spreadRadius: -20,
              offset: const Offset(0, 22)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kPanelRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Vim.cardTop, Vim.cardBottom],
            ),
            border: Border.all(color: Vim.stroke),
            borderRadius: BorderRadius.circular(kPanelRadius),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  const _DragHandle(),
                  const CommandBar(),
                  const Divider(height: 1, thickness: 1, color: Vim.stroke),
                  const Expanded(child: TimerListView()),
                  const _Footer(),
                ],
              ),
              Consumer(
                builder: (context, ref, _) {
                  final settings = ref.watch(settingsSheetOpenProvider);
                  final help = ref.watch(helpOpenProvider);
                  return Stack(
                    children: [
                      if (settings) const Positioned.fill(child: SettingsSheet()),
                      if (help) const Positioned.fill(child: HelpOverlay()),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (reduceMotion) return panel;
    // Drop from the menu bar and expand from the top-centre, Dynamic Island style.
    return panel
        .animate()
        .fadeIn(duration: 140.ms)
        .slideY(begin: -0.05, end: 0, duration: 380.ms, curve: Curves.easeOutCubic)
        .scaleXY(
          begin: 0.90,
          end: 1,
          alignment: Alignment.topCenter,
          duration: 460.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: 22,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Vim.strokeStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timers = ref.watch(timerEngineProvider);
    final active = timers.where((t) => t.isRunning || t.isPaused).length;
    final selected = ref.watch(selectedTimerIdProvider) != null;

    final String hint;
    if (selected) {
      hint = '␣ pause · ⏎ restart · x delete · ? help';
    } else if (timers.isNotEmpty) {
      hint = 'j / k to select · : commands · ? help';
    } else {
      hint = 'type a timer · : commands · ? help';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Vim.stroke)),
      ),
      child: Row(
        children: [
          Text(
            active == 0 ? 'Ready' : '$active active',
            style: const TextStyle(color: Vim.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: selected ? Vim.mint.withValues(alpha: 0.85) : Vim.textFaint,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('⌘,',
              style: TextStyle(color: Vim.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          GlassIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onTap: () => ref.read(settingsSheetOpenProvider.notifier).state = true,
          ),
        ],
      ),
    );
  }
}
