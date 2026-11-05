import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:intl/intl.dart';

/// A clock time like `3:45 PM`, with Bangla digits when the app is in Bangla.
/// Newer date formats put a narrow no-break space before AM/PM; a plain space
/// reads the same and matches what people type.
String formatClockTime(DateTime time) =>
    localizeDigits(DateFormat.jm().format(time).replaceAll('\u202f', ' '));

/// A day and time like `5 Nov, 3:45 PM` (the year is added when it is not
/// [now]'s year).
String formatDayAndTime(DateTime when, DateTime now) => localizeDigits(
  DateFormat(when.year == now.year ? 'd MMM, h:mm a' : 'd MMM yyyy, h:mm a')
      .format(when),
);

/// Asks for a day (never after today) and then a time of that day. Returns
/// null when either question is cancelled.
Future<DateTime?> pickDayAndTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime now,
}) async {
  final today = dateOnly(now);
  final day = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(now) ? today : dateOnly(initial),
    firstDate: DateTime(2000),
    lastDate: today,
    currentDate: today,
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}
