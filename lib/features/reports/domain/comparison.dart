import 'package:hishab/core/utils/percent.dart';

enum ChangeDirection {
  /// Both periods have nothing.
  none,
  up,
  down,
  same,
}

/// A figure of this period next to the same figure of the period before.
class Comparison {
  const Comparison({required this.current, required this.previous});

  final int current;
  final int previous;

  /// Positive when [current] is bigger.
  int get difference => current - previous;

  /// The change in whole percent, or null when [previous] is zero.
  int? get percent => percentChange(current: current, previous: previous);

  ChangeDirection get direction {
    if (current == 0 && previous == 0) return ChangeDirection.none;
    if (difference > 0) return ChangeDirection.up;
    if (difference < 0) return ChangeDirection.down;
    return ChangeDirection.same;
  }
}
