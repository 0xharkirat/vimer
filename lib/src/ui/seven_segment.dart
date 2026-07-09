import 'package:flutter/material.dart';

/// A classic seven-segment LCD readout, drawn by hand so it needs no font.
///
/// Off segments are painted faintly (the "ghost" segments you see on a real
/// transflective / memory-in-pixel display), and lit segments get a soft glow,
/// which together give it that digital-clock vibe.
class SevenSegmentDisplay extends StatelessWidget {
  const SevenSegmentDisplay({
    super.key,
    required this.text,
    required this.color,
    required this.offColor,
    this.height = 46,
    this.glow = true,
  });

  final String text;
  final Color color;
  final Color offColor;
  final double height;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(sevenSegWidth(text, height), height),
      painter: _SevenSegPainter(
        text: text,
        color: color,
        offColor: offColor,
        glow: glow,
      ),
    );
  }
}

double _digitW(double h) => 0.60 * h;
double _colonW(double h) => 0.34 * h;
double _dotW(double h) => 0.30 * h;
double _charGap(double h) => 0.12 * h;

double _glyphW(String ch, double h) =>
    ch == ':' ? _colonW(h) : (ch == '.' ? _dotW(h) : _digitW(h));

double sevenSegWidth(String text, double h) {
  var w = 0.0;
  for (var i = 0; i < text.length; i++) {
    w += _glyphW(text[i], h);
    if (i < text.length - 1) w += _charGap(h);
  }
  return w;
}

// Which of segments a..g are lit for each digit.
const Map<String, String> _segMap = {
  '0': 'abcdef',
  '1': 'bc',
  '2': 'abged',
  '3': 'abgcd',
  '4': 'fgbc',
  '5': 'afgcd',
  '6': 'afgecd',
  '7': 'abc',
  '8': 'abcdefg',
  '9': 'abcdfg',
};

class _SevenSegPainter extends CustomPainter {
  _SevenSegPainter({
    required this.text,
    required this.color,
    required this.offColor,
    required this.glow,
  });

  final String text;
  final Color color;
  final Color offColor;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final t = 0.135 * h;
    var x = 0.0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == ':') {
        _drawColon(canvas, x, h, t);
      } else if (ch == '.') {
        _drawDot(canvas, x, h, t);
      } else {
        _drawDigit(canvas, x, h, _digitW(h), t, ch);
      }
      x += _glyphW(ch, h) + _charGap(h);
    }
  }

  void _drawDot(Canvas canvas, double ox, double h, double t) {
    final cx = ox + _dotW(h) / 2;
    final cy = h - t * 0.9;
    final r = t * 0.55;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      Radius.circular(r * 0.4),
    );
    if (glow) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.5),
      );
    }
    canvas.drawRRect(rect, Paint()..color = color);
  }

  void _drawColon(Canvas canvas, double ox, double h, double t) {
    final cx = ox + _colonW(h) / 2;
    final r = t * 0.55;
    final paint = Paint()..color = color;
    for (final cy in [h * 0.36, h * 0.66]) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        Radius.circular(r * 0.4),
      );
      if (glow) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.5),
        );
      }
      canvas.drawRRect(rect, paint);
    }
  }

  void _drawDigit(Canvas canvas, double ox, double h, double w, double t, String ch) {
    final lit = _segMap[ch] ?? '';
    final hLen = w - t;
    final vLen = h / 2 - t * 1.15;

    // (isHorizontal, centerX, centerY, length)
    final segs = <String, (bool, double, double, double)>{
      'a': (true, ox + w / 2, t / 2, hLen),
      'g': (true, ox + w / 2, h / 2, hLen),
      'd': (true, ox + w / 2, h - t / 2, hLen),
      'f': (false, ox + t / 2, h / 4, vLen),
      'b': (false, ox + w - t / 2, h / 4, vLen),
      'e': (false, ox + t / 2, h * 3 / 4, vLen),
      'c': (false, ox + w - t / 2, h * 3 / 4, vLen),
    };

    segs.forEach((name, s) {
      final path = s.$1 ? _hHex(s.$2, s.$3, s.$4, t) : _vHex(s.$2, s.$3, s.$4, t);
      if (lit.contains(name)) {
        if (glow) {
          canvas.drawPath(
            path,
            Paint()
              ..color = color.withValues(alpha: 0.45)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.45),
          );
        }
        canvas.drawPath(path, Paint()..color = color);
      } else {
        canvas.drawPath(path, Paint()..color = offColor);
      }
    });
  }

  Path _hHex(double cx, double cy, double len, double t) {
    final hl = len / 2, ht = t / 2;
    return Path()
      ..moveTo(cx - hl, cy)
      ..lineTo(cx - hl + ht, cy - ht)
      ..lineTo(cx + hl - ht, cy - ht)
      ..lineTo(cx + hl, cy)
      ..lineTo(cx + hl - ht, cy + ht)
      ..lineTo(cx - hl + ht, cy + ht)
      ..close();
  }

  Path _vHex(double cx, double cy, double len, double t) {
    final hl = len / 2, ht = t / 2;
    return Path()
      ..moveTo(cx, cy - hl)
      ..lineTo(cx + ht, cy - hl + ht)
      ..lineTo(cx + ht, cy + hl - ht)
      ..lineTo(cx, cy + hl)
      ..lineTo(cx - ht, cy + hl - ht)
      ..lineTo(cx - ht, cy - hl + ht)
      ..close();
  }

  @override
  bool shouldRepaint(_SevenSegPainter old) =>
      old.text != text || old.color != color || old.offColor != offColor || old.glow != glow;
}
