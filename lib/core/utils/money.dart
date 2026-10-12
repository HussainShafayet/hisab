import 'package:hishab/core/l10n/translator.dart';
import 'package:intl/intl.dart';

/// Money is always an `int` number of poisha (1 BDT = 100 poisha), never a
/// `double`. These helpers convert to and from the text people read and type.
const poishaPerTaka = 100;

/// Largest amount accepted from text input: 999,999,999,999 BDT.
const _maxTakaDigits = 12;

// en_IN groups digits the South Asian way: 12,34,567 (lakh and crore).
final _takaGrouping = NumberFormat.decimalPattern('en_IN');

/// `123456` -> `৳1,234.56`. Negative amounts become `-৳1,234.56`.
/// Pass `symbol: false` for a bare number, e.g. `1,234.56`.
String formatPoisha(int poisha, {bool symbol = true}) {
  final absolute = poisha.abs();
  final taka = _takaGrouping.format(absolute ~/ poishaPerTaka);
  final paisa = (absolute % poishaPerTaka).toString().padLeft(2, '0');
  final sign = poisha < 0 ? '-' : '';
  return localizeDigits('$sign${symbol ? '৳' : ''}$taka.$paisa');
}

/// `123456` -> `1234.56` and `123400` -> `1234`. For filling a text field
/// that the user will edit, so no symbol and no digit grouping.
String poishaToInput(int poisha) {
  final sign = poisha < 0 ? '-' : '';
  final absolute = poisha.abs();
  final taka = absolute ~/ poishaPerTaka;
  final paisa = absolute % poishaPerTaka;
  if (paisa == 0) return '$sign$taka';
  return '$sign$taka.${paisa.toString().padLeft(2, '0')}';
}

/// `123450` -> `1234.50`, always with two decimals, no grouping and no
/// symbol: the form a spreadsheet reads as a number.
String poishaToFixed(int poisha) {
  final sign = poisha < 0 ? '-' : '';
  final absolute = poisha.abs();
  final paisa = (absolute % poishaPerTaka).toString().padLeft(2, '0');
  return '$sign${absolute ~/ poishaPerTaka}.$paisa';
}

final _amountPattern = RegExp(
  r'^(-)?(\d{1,'
  '$_maxTakaDigits'
  r'})(?:\.(\d{1,2}))?$',
);

/// Parses what a user typed, such as `1500`, `1,500.5` or `-250.75`, into
/// poisha. Returns null when the text is not a valid amount (more than two
/// decimals, letters, empty, ...). Works on text, so there is no floating
/// point rounding.
int? parseTakaToPoisha(String input) {
  final cleaned = input.trim().replaceAll(',', '').replaceAll('৳', '').trim();
  final match = _amountPattern.firstMatch(cleaned);
  if (match == null) return null;

  final taka = int.parse(match.group(2)!);
  final paisa = int.parse((match.group(3) ?? '').padRight(2, '0'));
  final poisha = taka * poishaPerTaka + paisa;
  return match.group(1) == null ? poisha : -poisha;
}
