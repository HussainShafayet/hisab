import 'package:flutter/painting.dart';

/// Makes every digit the same width so amounts line up in columns.
///
/// Usage: `Theme.of(context).textTheme.titleLarge?.tabular`.
extension TabularFigures on TextStyle {
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
