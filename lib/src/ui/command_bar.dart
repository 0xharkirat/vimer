import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../services/duration_parser.dart';
import '../state/providers.dart';
import '../state/timer_engine.dart';
import '../theme.dart';
import '../util/format.dart';

/// The `:` command line's commands, for live suggestions + Tab completion.
const List<({String name, String hint})> _kCommands = [
  (name: 'settings', hint: 'preferences'),
  (name: 'clear', hint: 'remove all timers'),
  (name: 'help', hint: 'keyboard shortcuts'),
  (name: 'quit', hint: 'quit Vimer'),
];

/// Commands whose name starts with [prefix] (all of them when it's empty).
List<({String name, String hint})> _commandMatches(String prefix) {
  if (prefix.isEmpty) return _kCommands;
  return _kCommands.where((c) => c.name.startsWith(prefix)).toList();
}

/// The Spotlight-style input: type a duration, see a live preview, press Enter.
class CommandBar extends ConsumerStatefulWidget {
  const CommandBar({super.key});

  @override
  ConsumerState<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends ConsumerState<CommandBar>
    with SingleTickerProviderStateMixin, WindowListener {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  ParsedCommand? _preview;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _fieldFocus.addListener(_onFieldFocusChange);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _fieldFocus.removeListener(_onFieldFocusChange);
    _controller.dispose();
    _fieldFocus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFieldFocusChange() {
    // Typing beats selecting: focusing the field exits keyboard-control mode.
    if (_fieldFocus.hasFocus && ref.read(selectedTimerIdProvider) != null) {
      ref.read(selectedTimerIdProvider.notifier).state = null;
    }
  }

  /// The panel became key (launch, tray click, or summon hotkey): put the
  /// cursor back in the command field so you can always just start typing.
  @override
  void onWindowFocus() => _refocus();

  bool get _overlayOpen =>
      ref.read(settingsSheetOpenProvider) || ref.read(helpOpenProvider);

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedTimerIdProvider.notifier).state = null;
      if (!_overlayOpen) _fieldFocus.requestFocus();
    });
  }

  void _onChanged(String value) => setState(() => _preview = parseCommand(value));

  void _submit() {
    final text = _controller.text.trim();

    // Vim-style command line: ":q", ":settings", ":clear", ":help".
    if (text.startsWith(':')) {
      if (_runCommand(text.substring(1).trim().toLowerCase())) {
        _controller.clear();
        setState(() => _preview = null);
        // Don't grab focus back if the command opened an overlay (Settings /
        // Help) - its Esc-to-close needs focus, not this field.
        if (!_overlayOpen) _fieldFocus.requestFocus();
      } else if (text.length > 1) {
        _shake.forward(from: 0);
      }
      return;
    }

    final created = ref.read(timerEngineProvider.notifier).add(_controller.text);
    if (created == null) {
      if (text.isNotEmpty) _shake.forward(from: 0);
      return;
    }
    _controller.clear();
    setState(() => _preview = null);
    _fieldFocus.requestFocus();
  }

  bool _runCommand(String cmd) {
    switch (cmd) {
      case 'q':
      case 'quit':
        ref.read(nativeServiceProvider).onQuit?.call();
        return true;
      case 'set':
      case 'settings':
        ref.read(settingsSheetOpenProvider.notifier).state = true;
        return true;
      case 'clear':
        ref.read(timerEngineProvider.notifier).clearAll();
        return true;
      case 'help':
      case '?':
        ref.read(helpOpenProvider.notifier).state = true;
        return true;
      case 'notch':
        ref.read(nativeServiceProvider).toggleNotch();
        return true;
      default:
        return false;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Down arrow drops into the timer list for keyboard control.
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final timers = ref.read(timerEngineProvider);
      if (timers.isNotEmpty) {
        ref.read(selectedTimerIdProvider.notifier).state = timers.first.id;
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_controller.text.isNotEmpty) {
        _controller.clear();
        setState(() => _preview = null);
      } else {
        ref.read(nativeServiceProvider).hide();
      }
      return KeyEventResult.handled;
    }
    // Tab completes a `:` command to the first match (and is swallowed so it
    // doesn't move focus out of the field).
    if (event.logicalKey == LogicalKeyboardKey.tab && _controller.text.startsWith(':')) {
      final matches = _commandMatches(_controller.text.substring(1).trim().toLowerCase());
      if (matches.isNotEmpty) {
        final done = ':${matches.first.name}';
        _controller.value = TextEditingValue(
          text: done,
          selection: TextSelection.collapsed(offset: done.length),
        );
        setState(() => _preview = null);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsSheetOpenProvider, (prev, next) {
      if (prev == true && next == false) _refocus();
    });
    // When Help closes, return to the input - unless a timer is selected, in
    // which case the list reclaims focus (see timer_list.dart).
    ref.listen(helpOpenProvider, (prev, next) {
      if (prev == true && next == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_overlayOpen && ref.read(selectedTimerIdProvider) == null) {
            _fieldFocus.requestFocus();
          }
        });
      }
    });
    ref.listen(selectedTimerIdProvider, (prev, next) {
      if (next == null && prev != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_overlayOpen) _fieldFocus.requestFocus();
        });
      }
    });
    // ":" from the list prefills the field so you keep typing the command.
    ref.listen(pendingInputProvider, (prev, next) {
      if (next == null) return;
      _controller.text = next;
      _controller.selection = TextSelection.collapsed(offset: next.length);
      setState(() => _preview = parseCommand(next));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fieldFocus.requestFocus();
      });
      ref.read(pendingInputProvider.notifier).state = null;
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 5) * (1 - t) * 9;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: _field(),
          ),
          const SizedBox(height: 8),
          _previewRow(),
        ],
      ),
    );
  }

  Widget _field() {
    return Focus(
      onKeyEvent: _onKey,
      child: Container(
        decoration: BoxDecoration(
          color: Vim.fieldFill,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Vim.strokeStrong),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 20, color: Vim.textDim),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _fieldFocus,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.go,
                cursorColor: Vim.mint,
                cursorWidth: 2,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: Vim.text),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                  border: InputBorder.none,
                  hintText: 'Set a timer…  25m deep work',
                  hintStyle: TextStyle(color: Vim.textFaint, fontWeight: FontWeight.w400),
                ),
              ),
            ),
            _enterHint(),
          ],
        ),
      ),
    );
  }

  Widget _enterHint() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: _preview != null ? 1 : 0,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Vim.mint.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Text('↵',
            style: TextStyle(color: Vim.mint, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  Widget _previewRow() {
    final preview = _preview;
    final Widget child;
    if (_controller.text.startsWith(':')) {
      child = _commandSuggestions();
    } else if (preview != null) {
      child = _previewChip(preview);
    } else {
      child = _hintText();
    }
    return SizedBox(
      height: 22,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }

  /// The `:` command palette: matching commands, first one (the Tab target)
  /// highlighted. Shown in place of the natural-language hint while typing `:`.
  Widget _commandSuggestions() {
    final matches = _commandMatches(_controller.text.substring(1).trim().toLowerCase());
    if (matches.isEmpty) {
      return const Row(
        key: ValueKey('cmd-none'),
        children: [
          Icon(Icons.help_outline_rounded, size: 13, color: Vim.textFaint),
          SizedBox(width: 6),
          Flexible(
            child: Text('no matching command',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Vim.textFaint, fontSize: 12)),
          ),
        ],
      );
    }
    return Row(
      key: const ValueKey('cmd'),
      children: [
        const Text('⇥',
            style: TextStyle(color: Vim.textFaint, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        for (var i = 0; i < matches.length; i++) ...[
          if (i > 0) _dot(),
          Text(
            ':${matches[i].name}',
            style: TextStyle(
              color: i == 0 ? Vim.mint : Vim.textDim,
              fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _hintText() {
    return const Row(
      key: ValueKey('hint'),
      children: [
        Icon(Icons.bolt_rounded, size: 14, color: Vim.textFaint),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            '25m · @3pm · stopwatch · #project · “5m tea”',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Vim.textFaint, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _previewChip(ParsedCommand cmd) {
    final String main;
    final String sub;
    if (cmd.kind == CommandKind.stopwatch) {
      main = 'Stopwatch';
      sub = 'counts up';
    } else if (cmd.kind == CommandKind.alarm && cmd.fireAt != null) {
      main = formatClock(cmd.duration!);
      sub = 'at ${formatEndTime(cmd.fireAt!)}';
    } else {
      main = formatClock(cmd.duration!);
      sub = 'ends ${formatEndTime(DateTime.now().add(cmd.duration!))}';
    }
    return Row(
      key: const ValueKey('preview'),
      children: [
        Icon(
          cmd.kind == CommandKind.stopwatch ? Icons.timer_outlined : Icons.play_circle_fill_rounded,
          size: 15,
          color: Vim.mint,
        ),
        const SizedBox(width: 6),
        Text(
          main,
          style: const TextStyle(
              color: Vim.text, fontWeight: FontWeight.w700, fontSize: 13, fontFeatures: kTabular),
        ),
        if (cmd.label != null) ...[
          _dot(),
          Flexible(
            child: Text(
              cmd.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Vim.mint, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
        for (final tag in cmd.tags.take(2)) ...[
          const SizedBox(width: 6),
          Text('#$tag',
              style: const TextStyle(color: Vim.blue, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
        _dot(),
        Text(sub, style: const TextStyle(color: Vim.textDim, fontSize: 12)),
      ],
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 7),
        child: Text('·', style: TextStyle(color: Vim.textFaint)),
      );
}
