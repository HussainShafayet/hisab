import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/dates.dart';

void main() {
  test('dateOnly drops the time of day', () {
    expect(
      dateOnly(DateTime(2026, 10, 11, 23, 59, 59)),
      DateTime(2026, 10, 11),
    );
  });

  test('isSameDay compares the calendar day only', () {
    expect(
      isSameDay(DateTime(2026, 10, 11, 0, 0), DateTime(2026, 10, 11, 23, 59)),
      isTrue,
    );
    expect(isSameDay(DateTime(2026, 10, 11), DateTime(2026, 10, 12)), isFalse);
    expect(isSameDay(DateTime(2026, 10, 11), DateTime(2025, 10, 11)), isFalse);
  });

  test('monthStart is midnight on the 1st', () {
    expect(monthStart(DateTime(2026, 10, 31, 18, 30)), DateTime(2026, 10));
  });

  group('addMonths', () {
    test('moves forward and back', () {
      expect(addMonths(DateTime(2026, 10), 1), DateTime(2026, 11));
      expect(addMonths(DateTime(2026, 10), -1), DateTime(2026, 9));
    });

    test('crosses year boundaries', () {
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
      expect(addMonths(DateTime(2026, 3), -15), DateTime(2024, 12));
    });

    test('does not overflow from a day that the target month lacks', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2));
    });
  });

  group('monthRange', () {
    test('runs from the 1st to the 1st of the next month', () {
      final range = monthRange(DateTime(2026, 10, 15, 12));
      expect(range.start, DateTime(2026, 10));
      expect(range.end, DateTime(2026, 11));
    });

    test('works for December and February', () {
      expect(monthRange(DateTime(2026, 12, 31)).end, DateTime(2027));
      expect(monthRange(DateTime(2028, 2, 29)).end, DateTime(2028, 3));
    });

    test('includes the last second of the month and excludes the next 1st', () {
      final range = monthRange(DateTime(2026, 10));
      final lastSecond = DateTime(2026, 10, 31, 23, 59, 59);
      expect(
        !lastSecond.isBefore(range.start) && lastSecond.isBefore(range.end),
        isTrue,
      );
      expect(DateTime(2026, 11).isBefore(range.end), isFalse);
    });
  });

  test('combineDayWithTime keeps the day and takes the clock time', () {
    expect(
      combineDayWithTime(DateTime(2026, 10, 9), DateTime(2030, 1, 1, 14, 5, 7)),
      DateTime(2026, 10, 9, 14, 5, 7),
    );
  });
}
