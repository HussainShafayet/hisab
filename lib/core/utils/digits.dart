const _bengaliDigits = '০১২৩৪৫৬৭৮৯';

/// Replaces Bengali digits (০-৯) with 0-9, so numbers and dates typed in
/// Bangla can be read the same way as English ones.
String normalizeDigits(String text) {
  final buffer = StringBuffer();
  for (final unit in text.split('')) {
    final index = _bengaliDigits.indexOf(unit);
    buffer.write(index >= 0 ? '$index' : unit);
  }
  return buffer.toString();
}
