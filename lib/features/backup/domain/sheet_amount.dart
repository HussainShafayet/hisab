import 'package:hishab/core/utils/digits.dart';

final _currencyWords = RegExp(r'৳|tk\.?|bdt|taka', caseSensitive: false);
final _amountText = RegExp(r'^(\d{0,12})(?:\.(\d*))?$');

/// Reads an amount the way a spreadsheet shows it and returns poisha, with
/// the sign kept (`-250` is -25000). Understands:
/// * currency marks and words: `৳1,200`, `Tk 1200`, `1200 BDT`
/// * grouping with commas or spaces, in any style: `1,20,000.50`, `1 200`
/// * Bengali digits: `১২০০`
/// * a minus sign, a trailing minus, or brackets for negative: `-5`, `5-`, `(5)`
/// More than two decimals are rounded to the nearest poisha, since a sheet
/// often holds the result of a division like `33.3333`.
///
/// Returns null when [raw] is not a number or is beyond 12 digits of taka.
int? parseSheetAmount(String raw) {
  var text = normalizeDigits(raw).replaceAll('−', '-').trim();
  var negative = false;

  if (text.startsWith('(') && text.endsWith(')')) {
    negative = true;
    text = text.substring(1, text.length - 1);
  }
  text = text.replaceAll(_currencyWords, '').replaceAll(RegExp(r'[,\s]'), '');
  if (text.startsWith('+')) text = text.substring(1);
  if (text.startsWith('-')) {
    negative = !negative;
    text = text.substring(1);
  } else if (text.endsWith('-')) {
    negative = !negative;
    text = text.substring(0, text.length - 1);
  }

  final match = _amountText.firstMatch(text);
  if (match == null) return null;
  final whole = match.group(1) ?? '';
  final fraction = match.group(2) ?? '';
  if (whole.isEmpty && fraction.isEmpty) return null;

  final taka = whole.isEmpty ? 0 : int.parse(whole);
  var paisa = int.parse(fraction.padRight(2, '0').substring(0, 2));
  if (fraction.length > 2 && int.parse(fraction[2]) >= 5) paisa += 1;
  final poisha = taka * 100 + paisa;
  return negative ? -poisha : poisha;
}
