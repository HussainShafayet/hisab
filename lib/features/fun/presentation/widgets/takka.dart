import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/features/fun/domain/takka_mood.dart';

/// Takka, the little taka coin that lives in the app. It hops when it shows
/// and when it is tapped (never for ever, so a screen can still settle).
class Takka extends StatefulWidget {
  const Takka({
    this.mood = TakkaMood.happy,
    this.size = 64,
    this.onTap,
    super.key,
  });

  final TakkaMood mood;
  final double size;
  final VoidCallback? onTap;

  @override
  State<Takka> createState() => _TakkaState();
}

class _TakkaState extends State<Takka> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!motionOff(context)) _hop.forward();
  }

  @override
  void didUpdateWidget(Takka old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood && !motionOff(context)) _hop.forward(from: 0);
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  void _tap() {
    if (!motionOff(context)) _hop.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      label: tr('Takka the coin'),
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _tap,
        child: AnimatedBuilder(
          animation: _hop,
          builder: (context, _) {
            final t = _hop.value;
            // Two hops that get smaller.
            final lift = math.sin(t * math.pi * 4).abs() * (1 - t) * 0.16;
            return SizedBox(
              width: size,
              height: size,
              child: Transform.translate(
                offset: Offset(0, -lift * size),
                child: CustomPaint(painter: _TakkaPainter(widget.mood)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TakkaPainter extends CustomPainter {
  const _TakkaPainter(this.mood);

  final TakkaMood mood;

  static const _ink = Color(0xFF4E342E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s * 0.5, s * 0.6);
    final r = s * 0.36;

    // Shadow on the ground.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.96),
        width: s * 0.5,
        height: s * 0.07,
      ),
      Paint()..color = const Color(0x22000000),
    );

    // The coin.
    canvas
      ..drawCircle(
        center,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [Color(0xFFFFF59D), Color(0xFFFFC107), Color(0xFFFF9800)],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      )
      ..drawCircle(
        center,
        r - s * 0.025,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..color = const Color(0xCCE65100),
      );

    // The taka sign, pressed into the coin.
    _text(canvas, '৳', center.translate(0, s * 0.03), s * 0.46, 0x2E4E342E);

    _face(canvas, center, s);
    _extras(canvas, center, r, s);
  }

  void _text(Canvas canvas, String text, Offset at, double fontSize, int argb) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Color(argb),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  void _face(Canvas canvas, Offset c, double s) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.035
      ..color = _ink;
    final fill = Paint()..color = _ink;
    final left = c.translate(-s * 0.13, -s * 0.06);
    final right = c.translate(s * 0.13, -s * 0.06);

    switch (mood) {
      case TakkaMood.happy || TakkaMood.worried:
        for (final eye in [left, right]) {
          canvas
            ..drawOval(
              Rect.fromCenter(center: eye, width: s * 0.07, height: s * 0.1),
              fill,
            )
            ..drawCircle(
              eye.translate(-s * 0.01, -s * 0.02),
              s * 0.014,
              Paint()..color = Colors.white,
            );
        }
      case TakkaMood.sleepy:
        for (final eye in [left, right]) {
          canvas.drawArc(
            Rect.fromCenter(center: eye, width: s * 0.1, height: s * 0.07),
            0.2,
            math.pi - 0.4,
            false,
            line,
          );
        }
      case TakkaMood.party:
        for (final eye in [left, right]) {
          canvas.drawArc(
            Rect.fromCenter(center: eye, width: s * 0.1, height: s * 0.08),
            math.pi + 0.2,
            math.pi - 0.4,
            false,
            line,
          );
        }
    }

    final mouth = c.translate(0, s * 0.1);
    switch (mood) {
      case TakkaMood.happy:
        canvas.drawArc(
          Rect.fromCenter(center: mouth, width: s * 0.2, height: s * 0.12),
          0.3,
          math.pi - 0.6,
          false,
          line,
        );
      case TakkaMood.worried:
        canvas.drawArc(
          Rect.fromCenter(
            center: mouth.translate(0, s * 0.03),
            width: s * 0.16,
            height: s * 0.09,
          ),
          math.pi + 0.3,
          math.pi - 0.6,
          false,
          line,
        );
        // Eyebrows, slanting up in the middle.
        for (final side in [-1.0, 1.0]) {
          final eye = c.translate(side * s * 0.13, -s * 0.06);
          canvas.drawLine(
            eye.translate(-side * s * 0.05, -s * 0.085),
            eye.translate(side * s * 0.05, -s * 0.12),
            line,
          );
        }
      case TakkaMood.sleepy:
        canvas.drawOval(
          Rect.fromCenter(center: mouth, width: s * 0.06, height: s * 0.07),
          fill,
        );
      case TakkaMood.party:
        canvas.drawArc(
          Rect.fromCenter(center: mouth, width: s * 0.22, height: s * 0.2),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0xFFB71C1C),
        );
    }

    if (mood == TakkaMood.happy || mood == TakkaMood.party) {
      final cheek = Paint()..color = const Color(0x55F06292);
      canvas
        ..drawCircle(c.translate(-s * 0.22, s * 0.05), s * 0.04, cheek)
        ..drawCircle(c.translate(s * 0.22, s * 0.05), s * 0.04, cheek);
    }
  }

  void _extras(Canvas canvas, Offset c, double r, double s) {
    switch (mood) {
      case TakkaMood.worried:
        // A sweat drop.
        final x = c.dx + r * 0.85;
        final y = c.dy - r * 0.55;
        final drop = Path()
          ..moveTo(x, y - s * 0.07)
          ..quadraticBezierTo(x + s * 0.06, y + s * 0.01, x, y + s * 0.04)
          ..quadraticBezierTo(x - s * 0.06, y + s * 0.01, x, y - s * 0.07);
        canvas.drawPath(drop, Paint()..color = const Color(0xFF4FC3F7));
      case TakkaMood.sleepy:
        _text(
          canvas,
          'z',
          Offset(c.dx + r * 0.9, c.dy - r * 0.8),
          s * 0.2,
          0xFF5C6BC0,
        );
        _text(
          canvas,
          'z',
          Offset(c.dx + r * 1.1, c.dy - r * 1.1),
          s * 0.14,
          0xAA5C6BC0,
        );
      case TakkaMood.party:
        // A party hat on top, a little to one side.
        final top = Offset(c.dx + s * 0.05, c.dy - r - s * 0.15);
        final hat = Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(c.dx - s * 0.13, c.dy - r + s * 0.04)
          ..lineTo(c.dx + s * 0.2, c.dy - r + s * 0.02)
          ..close();
        canvas
          ..drawPath(hat, Paint()..color = const Color(0xFFEF5350))
          ..drawCircle(top, s * 0.045, Paint()..color = const Color(0xFFFFEB3B))
          ..drawCircle(
            Offset(c.dx - r * 1.0, c.dy - r * 0.5),
            s * 0.02,
            Paint()..color = const Color(0xFF42A5F5),
          )
          ..drawCircle(
            Offset(c.dx + r * 1.0, c.dy - r * 0.1),
            s * 0.02,
            Paint()..color = const Color(0xFF66BB6A),
          );
      case TakkaMood.happy:
        break;
    }
  }

  @override
  bool shouldRepaint(_TakkaPainter old) => old.mood != mood;
}
