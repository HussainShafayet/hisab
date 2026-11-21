// The colors text is drawn in, against the colors it is drawn on, must meet
// WCAG AA: 4.5:1 for text, 3:1 for icons and outlines. Measured from the
// theme's own colors, so it holds for every screen that uses them.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/theme/app_theme.dart';
import 'package:hishab/core/theme/finance_colors.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _ratio(Color a, Color b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  for (final entry in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    group('${entry.key} theme contrast', () {
      final scheme = entry.value.colorScheme;
      final finance = entry.value.extension<FinanceColors>()!;
      // Everything a card, a chip or the page itself can be drawn on.
      final surfaces = {
        'surface': scheme.surface,
        'surfaceContainerLow': scheme.surfaceContainerLow,
        'surfaceContainer': scheme.surfaceContainer,
        'surfaceContainerHighest': scheme.surfaceContainerHighest,
      };

      test('text colors are readable on every surface', () {
        final texts = {
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
          'primary': scheme.primary,
          'error': scheme.error,
          'income': finance.income,
          'expense': finance.expense,
        };
        for (final text in texts.entries) {
          for (final surface in surfaces.entries) {
            expect(
              _ratio(text.value, surface.value),
              greaterThanOrEqualTo(4.5),
              reason: '${text.key} on ${surface.key}',
            );
          }
        }
      });

      test('text on a filled color is readable', () {
        final pairs = {
          'onPrimary on primary': _ratio(scheme.onPrimary, scheme.primary),
          'onError on error': _ratio(scheme.onError, scheme.error),
          'onPrimaryContainer on primaryContainer': _ratio(
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          ),
          'onSecondaryContainer on secondaryContainer': _ratio(
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ),
          'onTertiaryContainer on tertiaryContainer': _ratio(
            scheme.onTertiaryContainer,
            scheme.tertiaryContainer,
          ),
        };
        for (final pair in pairs.entries) {
          expect(pair.value, greaterThanOrEqualTo(4.5), reason: pair.key);
        }
      });

      test('outlines and icons are visible', () {
        for (final surface in surfaces.entries) {
          expect(
            _ratio(scheme.outline, surface.value),
            greaterThanOrEqualTo(3),
            reason: 'outline on ${surface.key}',
          );
        }
      });
    });
  }
}
