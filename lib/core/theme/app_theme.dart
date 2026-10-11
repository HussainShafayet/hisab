import 'package:flutter/material.dart';
import 'package:hishab/core/theme/finance_colors.dart';

/// Material 3 light and dark themes generated from a single seed color.
///
/// `abstract final class` is the Dart 3 idiom for a namespace of static members:
/// it can neither be instantiated nor extended.
abstract final class AppTheme {
  static const _seed = Color(0xFF00796B);

  static ThemeData light() => _build(Brightness.light, FinanceColors.light);

  static ThemeData dark() => _build(Brightness.dark, FinanceColors.dark);

  static ThemeData _build(Brightness brightness, FinanceColors finance) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [finance],
      appBarTheme: const AppBarTheme(centerTitle: false),
      // Five tabs on a 360 dp wide phone leave 72 dp each, and the default
      // label size wraps "Transactions" onto two lines.
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            letterSpacing: 0,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
