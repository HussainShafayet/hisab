import 'package:hishab/core/l10n/translator.dart';

/// `part` out of `whole` as a whole percent, rounded half up: `25%`. Anything
/// above zero but under half a percent shows as `<1%` so it is not mistaken
/// for nothing. A zero `whole` gives `0%`.
String formatPercent(int part, int whole) {
  if (whole <= 0 || part <= 0) return localizeDigits('0%');
  final percent = (part * 100 + whole ~/ 2) ~/ whole;
  return localizeDigits(percent == 0 ? '<1%' : '$percent%');
}

/// The change from [previous] to [current] in whole percent, rounded half
/// away from zero, or null when [previous] is zero (there is nothing to
/// compare with).
int? percentChange({required int current, required int previous}) {
  if (previous == 0) return null;
  final change = (current - previous) * 100;
  final magnitude = (change.abs() * 2 + previous.abs()) ~/ (previous.abs() * 2);
  final negative = (change < 0) != (previous < 0);
  return negative ? -magnitude : magnitude;
}
