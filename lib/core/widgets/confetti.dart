import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/motion.dart';

/// Throws confetti over the whole screen for about two seconds, then takes
/// itself away. It does nothing when the phone asks for no animations.
void showConfetti(BuildContext context) {
  if (motionOff(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Confetti(onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  static const _colors = [
    Color(0xFFEF5350),
    Color(0xFFFFCA28),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
  ];

  late final AnimationController _controller;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _pieces = [
      for (var i = 0; i < 80; i++)
        _Piece(
          x: random.nextDouble(),
          drift: (random.nextDouble() - 0.5) * 0.3,
          start: random.nextDouble() * 0.25,
          speed: 0.7 + random.nextDouble() * 0.6,
          size: 6 + random.nextDouble() * 6,
          spin: random.nextDouble() * 6,
          color: _colors[random.nextInt(_colors.length)],
        ),
    ];
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2200),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onDone();
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _controller.value),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.drift,
    required this.start,
    required this.speed,
    required this.size,
    required this.spin,
    required this.color,
  });

  final double x;
  final double drift;
  final double start;
  final double speed;
  final double size;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final local = ((t - piece.start) / (1 - piece.start)).clamp(0.0, 1.0);
      if (local == 0) continue;
      final y = -20 + (size.height + 40) * local * piece.speed;
      final x =
          size.width * (piece.x + piece.drift * local) +
          math.sin(local * 9 + piece.spin) * 14;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(piece.spin + local * 8)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.55,
          ),
          Paint()..color = piece.color.withValues(alpha: fade),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
