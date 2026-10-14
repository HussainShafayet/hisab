import 'package:flutter/material.dart';
import 'package:hishab/core/utils/money.dart';

/// True when the phone asks for no animations (a setting for people who feel
/// ill from motion, or who want to save battery). Every animation in the app
/// skips straight to its end then.
bool motionOff(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// An amount of taka that counts up to its value when it first shows, and
/// counts from the old to the new value when it changes.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount({
    required this.poisha,
    this.style,
    this.textKey,
    super.key,
  });

  final int poisha;
  final TextStyle? style;

  /// The key of the `Text` that shows the amount, for tests.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    if (motionOff(context)) {
      return Text(formatPoisha(poisha), key: textKey, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: poisha.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) =>
          Text(formatPoisha(value.round()), key: textKey, style: style),
    );
  }
}

/// Fades its child in while it slides up a little, [index] steps after the
/// first one, so a column of cards arrives one by one.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({required this.child, this.index = 0, super.key});

  final Widget child;

  /// 0 for the first card; later ones start a little later (up to 8 steps).
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _step = 70;
  static const _length = 420;

  late final AnimationController _controller;
  late final Animation<double> _curve;
  var _started = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.index.clamp(0, 8) * _step;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _length + delay),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / (_length + delay), 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionOff(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * 18),
          child: child,
        ),
      ),
    );
  }
}

/// Builds with a number that eases from 0 to [value] when it first shows (and
/// from the old to the new value when it changes), for rings and bars.
class AnimatedFraction extends StatelessWidget {
  const AnimatedFraction({
    required this.value,
    required this.builder,
    super.key,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    if (motionOff(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => builder(context, animated),
    );
  }
}
