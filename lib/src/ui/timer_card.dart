import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_model.dart';
import '../state/providers.dart';
import '../state/timer_engine.dart';
import '../theme.dart';
import '../util/format.dart';
import 'seven_segment.dart';
import 'widgets.dart';

/// Reactive wrapper: watches a single timer by id, tracks selection, and wires
/// engine controls. Clicking selects it; being selected scrolls it into view.
class TimerCard extends ConsumerStatefulWidget {
  const TimerCard({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends ConsumerState<TimerCard> {
  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final model = ref.watch(timerByIdProvider(id));
    if (model == null) return const SizedBox.shrink();
    final selected = ref.watch(selectedTimerIdProvider) == id;

    ref.listen(selectedTimerIdProvider, (prev, next) {
      if (next == id && prev != id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(context,
                alignment: 0.5, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
          }
        });
      }
    });

    final engine = ref.read(timerEngineProvider.notifier);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(selectedTimerIdProvider.notifier).state = id,
      child: TimerCardVisual(
        model: model,
        selected: selected,
        onToggle: () => engine.toggle(id),
        onRestart: () => engine.restart(id),
        onDismiss: () => engine.dismiss(id),
        onStop: engine.stopAllRinging,
      ),
    );
  }
}

/// A timer rendered as a small LCD "device": a seven-segment readout on a matte
/// screen, a depleting progress bar, and a caption. Repaints itself at frame
/// rate while live so the countdown and the ring blink stay smooth.
class TimerCardVisual extends StatefulWidget {
  const TimerCardVisual({
    super.key,
    required this.model,
    this.selected = false,
    this.onToggle,
    this.onRestart,
    this.onDismiss,
    this.onStop,
  });

  final TimerModel model;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onRestart;
  final VoidCallback? onDismiss;
  final VoidCallback? onStop;

  @override
  State<TimerCardVisual> createState() => _TimerCardVisualState();
}

class _TimerCardVisualState extends State<TimerCardVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _syncAnim();
  }

  @override
  void didUpdateWidget(covariant TimerCardVisual old) {
    super.didUpdateWidget(old);
    if (old.model.status != widget.model.status) _syncAnim();
  }

  void _syncAnim() {
    final animate = widget.model.isRunning || widget.model.isRinging;
    if (animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = AnimatedBuilder(animation: _ctrl, builder: (context, _) => _card());
    if (widget.model.isRinging) {
      return card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.012, duration: 1100.ms, curve: Curves.easeInOut);
    }
    return card;
  }

  Widget _card() {
    final model = widget.model;
    final now = DateTime.now();
    final ringing = model.isRinging;
    final done = model.isDone;
    final paused = model.isPaused;
    final frac = model.remainingFraction(now);
    final low = model.isRunning && frac <= 0.12;

    final base = ringing
        ? Vim.ring
        : done
            ? Vim.textFaint
            : low
                ? Vim.amber
                : Vim.timerColor(model.colorIndex);

    // Alarm-clock blink while ringing; dim while paused.
    final blinkOn = !ringing || (now.millisecondsSinceEpoch % 1000) < 560;
    final segColor = paused
        ? base.withValues(alpha: 0.5)
        : (ringing && !blinkOn ? base.withValues(alpha: 0.22) : base);
    final offColor = base.withValues(alpha: 0.06);
    final time = model.isStopwatch
        ? formatStopwatch(model.elapsed(now))
        : (model.isFinished ? '00:00' : formatClock(model.remaining(now)));

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: ringing
                ? const [Vim.screenTopWarm, Vim.screenBottomWarm]
                : const [Vim.screenTop, Vim.screenBottom],
          ),
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(
            color: widget.selected
                ? Vim.mint.withValues(alpha: 0.75)
                : ringing
                    ? Vim.ring.withValues(alpha: 0.5)
                    : low
                        ? Vim.amber.withValues(alpha: 0.3)
                        : Vim.stroke,
            width: widget.selected ? 1.5 : 1,
          ),
          boxShadow: [
            if (ringing)
              BoxShadow(color: Vim.ring.withValues(alpha: 0.22), blurRadius: 24, spreadRadius: -6),
            if (widget.selected)
              BoxShadow(color: Vim.mint.withValues(alpha: 0.16), blurRadius: 18, spreadRadius: -4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SevenSegmentDisplay(
                        text: time,
                        color: segColor,
                        offColor: offColor,
                        height: 50,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _controls(model),
              ],
            ),
            const SizedBox(height: 13),
            model.isStopwatch
                ? _stopwatchBar(base)
                : _progressBar(model.isFinished ? 0 : frac, base),
            const SizedBox(height: 10),
            _caption(model, now, base, blinkOn),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(double fraction, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth * fraction.clamp(0.0, 1.0);
        return Stack(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              height: 4,
              width: w,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stopwatchBar(Color color) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _tagChip(String tag, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text('#$tag',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.95))),
    );
  }

  Widget _caption(TimerModel model, DateTime now, Color base, bool blinkOn) {
    final String right;
    if (model.isStopwatch) {
      right = model.isPaused ? 'PAUSED' : 'STOPWATCH';
    } else if (model.isRinging) {
      right = 'ESC TO STOP';
    } else if (model.isDone) {
      right = 'DONE';
    } else if (model.isPaused) {
      right = 'PAUSED';
    } else if (model.isAlarm && model.fireAt != null) {
      right = 'AT ${formatEndTime(model.fireAt!).toUpperCase()}';
    } else {
      right = 'ENDS ${formatEndTime(model.endTime!).toUpperCase()}';
    }
    final rightColor = model.isRinging ? base.withValues(alpha: blinkOn ? 1 : 0.35) : Vim.textFaint;

    const style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2);
    final left = <Widget>[
      for (final tag in model.tags.take(3)) _tagChip(tag, base),
    ];
    if (model.label != null) {
      left.add(Flexible(
        child: Text(
          model.label!.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(color: model.isFinished ? Vim.textFaint : Vim.textDim),
        ),
      ));
    }

    return Row(
      children: [
        Expanded(child: Row(children: left)),
        const SizedBox(width: 8),
        Text(right, style: style.copyWith(color: rightColor)),
      ],
    );
  }

  Widget _controls(TimerModel model) {
    if (model.isRinging) {
      return _StopButton(onTap: widget.onStop ?? () {});
    }
    final buttons = <Widget>[];
    if (model.isRunning) {
      buttons.add(GlassIconButton(icon: Icons.pause_rounded, tooltip: 'Pause', onTap: widget.onToggle ?? () {}));
    } else if (model.isPaused) {
      buttons.add(GlassIconButton(icon: Icons.play_arrow_rounded, tooltip: 'Resume', color: Vim.mint, onTap: widget.onToggle ?? () {}));
    }
    if (model.isPaused || model.isDone) {
      buttons.add(GlassIconButton(icon: Icons.refresh_rounded, tooltip: 'Restart', onTap: widget.onRestart ?? () {}));
    }
    buttons.add(GlassIconButton(icon: Icons.close_rounded, tooltip: 'Dismiss', onTap: widget.onDismiss ?? () {}));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: (_hover || model.isPaused || model.isDone) ? 1 : 0.42,
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }
}

class _StopButton extends StatefulWidget {
  const _StopButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Vim.ring.withValues(alpha: _hover ? 0.95 : 0.82),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [BoxShadow(color: Vim.ring.withValues(alpha: 0.4), blurRadius: 14, spreadRadius: -2)],
          ),
          child: const Text('Stop', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13.5)),
        ),
      ),
    );
  }
}
