import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/theme/app_theme.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';

void main() {
  test('themes use Material 3 with the matching brightness', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.useMaterial3, isTrue);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
  });

  test('themes carry the income and expense colors', () {
    expect(
      AppTheme.light().extension<FinanceColors>(),
      same(FinanceColors.light),
    );
    expect(
      AppTheme.dark().extension<FinanceColors>(),
      same(FinanceColors.dark),
    );
  });

  test('income and expense colors differ and lerp to the target', () {
    const light = FinanceColors.light;
    expect(light.income, isNot(light.expense));
    expect(light.lerp(FinanceColors.dark, 1).income, FinanceColors.dark.income);
  });

  test('tabular extension enables tabular figures', () {
    final style = const TextStyle(fontSize: 20).tabular;
    expect(style.fontFeatures, isNotNull);
    expect(style.fontFeatures!.single.feature, 'tnum');
  });
}
