import 'package:hishab/core/utils/digits.dart';

/// The order of day, month and year in a date column.
enum SheetDateFormat {
  yearMonthDay('Year-Month-Day', '2026-10-11'),
  dayMonthYear('Day/Month/Year', '11/10/2026'),
  monthDayYear('Month/Day/Year', '10/11/2026');

  const SheetDateFormat(this.label, this.example);

  final String label;
  final String example;
}

const _monthNames = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

final _timePattern = RegExp(
  r'(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*([AaPp])\.?[Mm]\.?)?',
);

/// The time that is used when a date has none. Noon keeps the day the same in
/// every time zone.
const defaultImportHour = 12;

int? _month(String token) {
  final number = int.tryParse(token);
  if (number != null) return number;
  if (token.length < 3) return null;
  final index = _monthNames.indexOf(token.substring(0, 3).toLowerCase());
  return index < 0 ? null : index + 1;
}

/// Reads a date from a spreadsheet cell in the given [format]. The separator
/// may be `-`, `/`, `.` or a space, the month may be a name (`11 Oct 2026`),
/// a two digit year means 20xx, Bengali digits are fine, and a time such as
/// `14:30` or `2:30 PM` is used when there is one (otherwise 12:00).
///
/// Returns null when the text is not a real date: `31/02/2026` fails, and so
/// does a date in another order than [format].
DateTime? parseSheetDate(String raw, SheetDateFormat format) {
  var text = normalizeDigits(raw).trim();
  text = text.replaceAllMapped(RegExp(r'(\d)T(\d)'), (m) => '${m[1]} ${m[2]}');
  if (text.endsWith('Z')) text = text.substring(0, text.length - 1);

  var hour = defaultImportHour;
  var minute = 0;
  var second = 0;
  final time = _timePattern.firstMatch(text);
  if (time != null) {
    hour = int.parse(time.group(1)!);
    minute = int.parse(time.group(2)!);
    second = int.parse(time.group(3) ?? '0');
    final meridiem = time.group(4)?.toLowerCase();
    if (meridiem == 'p' && hour < 12) hour += 12;
    if (meridiem == 'a' && hour == 12) hour = 0;
    text = text.replaceRange(time.start, time.end, ' ');
  }
  if (hour > 23 || minute > 59 || second > 59) return null;

  final tokens = text
      .split(RegExp(r'[\s\-/.,]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.length != 3) return null;

  final String yearToken;
  final String monthToken;
  final String dayToken;
  switch (format) {
    case SheetDateFormat.yearMonthDay:
      // A year first has four digits; otherwise this is another order.
      if (tokens[0].length != 4) return null;
      [yearToken, monthToken, dayToken] = tokens;
    case SheetDateFormat.dayMonthYear:
      [dayToken, monthToken, yearToken] = tokens;
    case SheetDateFormat.monthDayYear:
      [monthToken, dayToken, yearToken] = tokens;
  }

  var year = int.tryParse(yearToken);
  final month = _month(monthToken);
  final day = int.tryParse(dayToken);
  if (year == null || month == null || day == null) return null;
  if (yearToken.length == 2) year += 2000;
  if (yearToken.length != 2 && yearToken.length != 4) return null;
  if (year < 1900 || year > 2200 || month < 1 || month > 12) return null;

  final date = DateTime(year, month, day, hour, minute, second);
  // DateTime rolls 31 Feb over into March: that is not a real date.
  return date.month == month && date.day == day ? date : null;
}

/// The format that reads at least 90% of [values] (blank ones are ignored),
/// or null when none does. A date like `10/11/2026` fits both
/// Day/Month/Year and Month/Day/Year; the first of the two wins, as dates in
/// Bangladesh are written day first. A value like `25/12/2026` settles it.
SheetDateFormat? detectDateFormat(Iterable<String> values) {
  final cells = [
    for (final value in values)
      if (value.trim().isNotEmpty) value,
  ];
  if (cells.isEmpty) return null;

  SheetDateFormat? best;
  var bestShare = 0.0;
  for (final format in SheetDateFormat.values) {
    final readable = cells
        .where((cell) => parseSheetDate(cell, format) != null)
        .length;
    final share = readable / cells.length;
    if (share > bestShare) {
      best = format;
      bestShare = share;
    }
  }
  return bestShare >= 0.9 ? best : null;
}
