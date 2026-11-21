import 'package:flutter/material.dart';

/// App-specific semantic colors that Material's [ColorScheme] has no slot for.
///
/// A [ThemeExtension] is Flutter's way of attaching custom tokens to the theme,
/// similar to extra CSS variables. Read them with `context.financeColors`.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.warning,
  });

  final Color income;
  final Color expense;

  /// Budget progress between 80% and 100%. At 100% and above use [expense].
  final Color warning;

  static const light = FinanceColors(
    // Dark enough for 4.5:1 on every surface of the light theme (cards and
    // chips included), see test/core/theme/theme_contrast_test.dart.
    income: Color(0xFF276B2B),
    expense: Color(0xFFBB2323),
    warning: Color(0xFFE65100),
  );

  static const dark = FinanceColors(
    income: Color(0xFF81C784),
    expense: Color(0xFFEF9A9A),
    warning: Color(0xFFFFB74D),
  );

  @override
  FinanceColors copyWith({Color? income, Color? expense, Color? warning}) {
    return FinanceColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension FinanceColorsContext on BuildContext {
  FinanceColors get financeColors =>
      Theme.of(this).extension<FinanceColors>() ?? FinanceColors.light;
}
