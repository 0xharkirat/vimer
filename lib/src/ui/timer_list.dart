import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_model.dart';
import '../state/providers.dart';
import '../state/timer_engine.dart';
import '../theme.dart';
import 'seven_segment.dart';
import 'timer_card.dart';

/// An AnimatedList kept in sync with the engine's timer list. It owns only
/// enter/exit animations; each [TimerCard] reads its own model reactively so
/// status changes (running -> ringing -> done) don't need list diffing.
class TimerListView extends ConsumerStatefulWidget {
  const TimerListView({super.key});

  @override
  ConsumerState<TimerListView> createState() => _TimerListViewState();
}

class _TimerListViewState extends ConsumerState<TimerListView> {
  final _listKey = GlobalKey<AnimatedListState>();
  final _listFocus = FocusNode(debugLabel: 'timerList');
  final List<String> _ids = [];
  Map<String, TimerModel> _byId = {};
  bool _pendingG = false; // first half of `gg`
  bool _pendingD = false; // first half of `dd`

  @override
  void initState() {
    super.initState();
    final initial = ref.read(timerEngineProvider);
    _ids.addAll(initial.map((t) => t.id));
    _byId = {for (final t in initial) t.id: t};
  }

  @override
  void dispose() {
    _listFocus.dispose();
    super.dispose();
  }

  /// Vim-style keyboard control while a timer is selected.
  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final timers = ref.read(timerEngineProvider);
    if (timers.isEmpty) return KeyEventResult.ignored;
    final selection = ref.read(selectedTimerIdProvider.notifier);
    final index = timers.indexWhere((t) => t.id == selection.state);
    final key = event.logicalKey;
    final engine = ref.read(timerEngineProvider.notifier);

    // gg -> first, G -> last, dd -> delete (multi-key; handled before reset).
    if (event is KeyDownEvent && key == LogicalKeyboardKey.keyG) {
      _pendingD = false;
      if (HardwareKeyboard.instance.isShiftPressed) {
        _pendingG = false;
        selection.state = timers.last.id;
      } else if (_pendingG) {
        _pendingG = false;
        selection.state = timers.first.id;
      } else {
        _pendingG = true;
      }
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && key == LogicalKeyboardKey.keyD) {
      _pendingG = false;
      if (_pendingD) {
        _pendingD = false;
        if (index >= 0) engine.dismiss(timers[index].id);
      } else {
        _pendingD = true;
      }
      return KeyEventResult.handled;
    }
    _pendingG = false;
    _pendingD = false;

    // Navigation (repeatable): j/down, k/up (up past the top -> input).
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ) {
      selection.state = timers[index < 0 || index + 1 >= timers.length ? (index < 0 ? 0 : index) : index + 1].id;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
      selection.state = index <= 0 ? null : timers[index - 1].id;
      return KeyEventResult.handled;
    }

    // The rest fire once per press.
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;

    // Mode switches (no selection needed).
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyI ||
        key == LogicalKeyboardKey.keyA) {
      selection.state = null; // back to the command field
      return KeyEventResult.handled;
    }
    if (event.character == ':') {
      ref.read(pendingInputProvider.notifier).state = ':';
      return KeyEventResult.handled;
    }
    if (event.character == '?') {
      ref.read(helpOpenProvider.notifier).state = true;
      return KeyEventResult.handled;
    }

    // Actions on the selected timer.
    if (index < 0) return KeyEventResult.ignored;
    final timer = timers[index];
    if (key == LogicalKeyboardKey.space) {
      engine.toggle(timer.id);
    } else if (key == LogicalKeyboardKey.keyP) {
      engine.pause(timer.id);
    } else if (key == LogicalKeyboardKey.keyR) {
      engine.resume(timer.id);
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      engine.restart(timer.id);
    } else if (key == LogicalKeyboardKey.keyS) {
      timer.isRinging ? engine.silence(timer.id) : engine.dismiss(timer.id);
    } else if (key == LogicalKeyboardKey.keyX ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      engine.dismiss(timer.id);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// When the selected timer is removed, move selection to a neighbour.
  void _fixSelection(List<TimerModel> prev, List<TimerModel> next) {
    final selId = ref.read(selectedTimerIdProvider);
    if (selId == null || next.any((t) => t.id == selId)) return;
    if (next.isEmpty) {
      ref.read(selectedTimerIdProvider.notifier).state = null;
      return;
    }
    final oldIndex = prev.indexWhere((t) => t.id == selId);
    final ni = (oldIndex < 0 ? next.length - 1 : oldIndex).clamp(0, next.length - 1);
    ref.read(selectedTimerIdProvider.notifier).state = next[ni].id;
  }

  void _sync(List<TimerModel> next) {
    final nextIds = next.map((t) => t.id).toList();

    // Removals first, descending so earlier indices stay valid.
    for (var i = _ids.length - 1; i >= 0; i--) {
      if (!nextIds.contains(_ids[i])) {
        final snapshot = _byId[_ids.removeAt(i)];
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _removed(snapshot, animation),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    // Insertions, ascending.
    for (var i = 0; i < nextIds.length; i++) {
      if (i >= _ids.length || _ids[i] != nextIds[i]) {
        _ids.insert(i, nextIds[i]);
        _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 420));
      }
    }

    _byId = {for (final t in next) t.id: t};
  }

  Widget _removed(TimerModel? model, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInCubic);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: model == null
            ? const SizedBox.shrink()
            : IgnorePointer(child: TimerCardVisual(model: model)),
      ),
    );
  }

  Widget _inserted(String id, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.14), end: Offset.zero).animate(curved),
          child: TimerCard(id: id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(timerEngineProvider, (prev, next) {
      _sync(next);
      _fixSelection(prev ?? const [], next);
    });
    ref.listen(selectedTimerIdProvider, (_, next) {
      if (next != null && !_listFocus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _listFocus.requestFocus();
        });
      }
    });
    // Reclaim focus when Help closes while a timer is still selected, so vim
    // keys keep working instead of dropping dead.
    ref.listen(helpOpenProvider, (prev, next) {
      if (prev == true && next == false && ref.read(selectedTimerIdProvider) != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _listFocus.requestFocus();
        });
      }
    });
    final isEmpty = ref.watch(timerEngineProvider).isEmpty;

    return Focus(
      focusNode: _listFocus,
      onKeyEvent: _onListKey,
      child: Stack(
        children: [
          AnimatedList(
            key: _listKey,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            initialItemCount: _ids.length,
            itemBuilder: (context, index, animation) => _inserted(_ids[index], animation),
          ),
          if (isEmpty) const _EmptyState(),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SevenSegmentDisplay(
            text: '00:00',
            color: Vim.mint.withValues(alpha: 0.20),
            offColor: Vim.mint.withValues(alpha: 0.05),
            height: 44,
            glow: false,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(begin: 0.5, duration: 1600.ms),
          const SizedBox(height: 22),
          const Text('No timers yet',
              style: TextStyle(color: Vim.textDim, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Type a duration above and press Enter',
              style: TextStyle(color: Vim.textFaint, fontSize: 12.5)),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_Hint('25m'), _Hint('1h30m'), _Hint('5m tea'), _Hint('90s')],
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Vim.fieldFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Vim.stroke),
      ),
      child: Text(text, style: const TextStyle(color: Vim.textDim, fontSize: 12, fontFeatures: kTabular)),
    );
  }
}
