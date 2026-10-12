import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:intl/intl.dart';

/// `October 2026`.
String monthLabel(DateTime month) => DateFormat('MMMM yyyy').format(month);

/// `Oct`: the short month name, for chart labels.
String shortMonthLabel(DateTime month) => DateFormat('MMM').format(month);

/// `Today`, `Yesterday`, or a date like `Sun, 11 Oct` (with the year when it
/// is not the current year). [now] decides what today is.
String dayLabel(DateTime day, DateTime now) {
  final today = dateOnly(now);
  if (isSameDay(day, today)) return tr('Today');
  if (isSameDay(day, DateTime(today.year, today.month, today.day - 1))) {
    return tr('Yesterday');
  }
  return DateFormat(day.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM yyyy')
      .format(day);
}

/// `1 Oct 2026 – 15 Oct 2026`. [DateRange.end] is not part of the range, so
/// the label shows the day before it.
String rangeLabel(DateRange range) {
  final format = DateFormat('d MMM yyyy');
  final last = DateTime(range.end.year, range.end.month, range.end.day - 1);
  return '${format.format(range.start)} – ${format.format(last)}';
}
