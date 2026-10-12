import 'package:flutter/material.dart';
import 'package:hishab/core/utils/dates.dart';

/// Asks for a range of days with the calendar. Returns null when cancelled.
/// The result's `end` is the midnight after the last day picked, like every
/// [DateRange], so the last day is included. The calendar stops at [today].
Future<DateRange?> pickDateRange(
  BuildContext context, {
  required DateTime today,
  DateRange? initial,
}) async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: today,
    currentDate: today,
    initialDateRange: initial == null
        ? null
        : DateTimeRange(
            start: initial.start,
            end: DateTime(
              initial.end.year,
              initial.end.month,
              initial.end.day - 1,
            ),
          ),
  );
  if (picked == null) return null;
  return (
    start: dateOnly(picked.start),
    end: DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
  );
}
