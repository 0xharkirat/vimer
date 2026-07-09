import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A small circular glass button that is fully keyboard-operable: it takes
/// focus (Tab), shows a focus ring, activates on Enter/Space, and dips on press.
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 32,
    this.iconSize = 16,
    this.color,
    this.filled = false,
    this.autofocus = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final bool filled;
  final bool autofocus;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hover = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? Vim.mint;
    final idle = widget.color ?? Vim.textDim;
    final active = widget.color ?? Vim.text;
    final lit = _hover || _focused;
    final bg = widget.filled
        ? accent.withValues(alpha: lit ? 0.26 : 0.18)
        : (lit ? Vim.glassFillStrong : Colors.transparent);

    Widget button = FocusableActionDetector(
      autofocus: widget.autofocus,
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
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.86 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: _focused
                    ? Vim.mint.withValues(alpha: 0.9)
                    : widget.filled
                        ? accent.withValues(alpha: 0.35)
                        : Colors.transparent,
                width: _focused ? 1.5 : 1,
              ),
              boxShadow: _focused
                  ? [BoxShadow(color: Vim.mint.withValues(alpha: 0.28), blurRadius: 9, spreadRadius: -1)]
                  : null,
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: lit ? active : idle),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// A pill-shaped segmented control. Focusable (Tab), with Left/Right arrows to
/// move the selection and a focus ring.
class VimSegmented<T> extends StatefulWidget {
  const VimSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.autofocus = false,
  });

  final T value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onChanged;
  final bool autofocus;

  @override
  State<VimSegmented<T>> createState() => _VimSegmentedState<T>();
}

class _VimSegmentedState<T> extends State<VimSegmented<T>> {
  bool _focused = false;

  void _move(int delta) {
    final i = widget.options.indexWhere((o) => o.value == widget.value);
    final start = i < 0 ? 0 : i;
    final ni = (start + delta).clamp(0, widget.options.length - 1);
    if (ni != i) widget.onChanged(widget.options[ni].value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _move(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Vim.fieldFill,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: _focused ? Vim.mint.withValues(alpha: 0.9) : Vim.stroke,
            width: _focused ? 1.5 : 1,
          ),
          boxShadow: _focused
              ? [BoxShadow(color: Vim.mint.withValues(alpha: 0.22), blurRadius: 9, spreadRadius: -1)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in widget.options)
              GestureDetector(
                onTap: () => widget.onChanged(opt.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: opt.value == widget.value ? Vim.glassFillStrong : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: opt.value == widget.value ? Vim.strokeStrong : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: opt.value == widget.value ? Vim.text : Vim.textDim,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
