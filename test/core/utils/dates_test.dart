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

  group('monthKey', () {
    test('is year-month with a two digit month', () {
      expect(monthKey(DateTime(2026, 10, 11)), '2026-10');
      expect(monthKey(DateTime(2026, 1, 31, 23, 59)), '2026-01');
      expect(monthKey(DateTime(2027, 12)), '2027-12');
    });
  });

  group('daysInMonth', () {
    test('knows month lengths', () {
      expect(daysInMonth(DateTime(2026, 1)), 31);
      expect(daysInMonth(DateTime(2026, 4, 15)), 30);
      expect(daysInMonth(DateTime(2026, 12, 31)), 31);
    });

    test('knows leap years', () {
      expect(daysInMonth(DateTime(2026, 2)), 28);
      expect(daysInMonth(DateTime(2028, 2)), 29);
      expect(daysInMonth(DateTime(2100, 2)), 28);
      expect(daysInMonth(DateTime(2000, 2)), 29);
    });
  });

  group('startOfWeek', () {
    test('weeks start on Sunday', () {
      // 11 Oct 2026 is a Sunday.
      expect(startOfWeek(DateTime(2026, 10, 11, 15)), DateTime(2026, 10, 11));
      expect(
        startOfWeek(DateTime(2026, 10, 12)),
        DateTime(2026, 10, 11),
      ); // Mon
      expect(
        startOfWeek(DateTime(2026, 10, 17, 23, 59)),
        DateTime(2026, 10, 11),
      ); // Sat
      expect(
        startOfWeek(DateTime(2026, 10, 18)),
        DateTime(2026, 10, 18),
      ); // next Sun
    });

    test('goes back over a month and a year end', () {
      expect(startOfWeek(DateTime(2026, 10, 1)), DateTime(2026, 9, 27)); // Thu
      expect(startOfWeek(DateTime(2026, 1, 1)), DateTime(2025, 12, 28)); // Thu
    });

    test('can start on Monday or Saturday instead', () {
      expect(
        startOfWeek(DateTime(2026, 10, 14), firstWeekday: DateTime.monday),
        DateTime(2026, 10, 12),
      );
      expect(
        startOfWeek(DateTime(2026, 10, 14), firstWeekday: DateTime.saturday),
        DateTime(2026, 10, 10),
      );
    });
  });

  group('daysBetween', () {
    test('counts calendar days', () {
      expect(daysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 11)), 10);
      expect(daysBetween(DateTime(2026, 10, 11), DateTime(2026, 10, 11)), 0);
      expect(daysBetween(DateTime(2026, 10, 11), DateTime(2026, 10, 1)), -10);
    });

    test('ignores the time of day and crosses month and year ends', () {
      expect(
        daysBetween(DateTime(2026, 10, 1, 23, 59), DateTime(2026, 10, 2, 0, 1)),
        1,
      );
      expect(daysBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 1);
      expect(daysBetween(DateTime(2026, 1), DateTime(2027, 1)), 365);
      expect(daysBetween(DateTime(2028, 1), DateTime(2029, 1)), 366);
    });
  });

  group('lastMonths', () {
    test('lists the months ending with the given one, oldest first', () {
      expect(lastMonths(DateTime(2026, 10, 20), 3), [
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
      ]);
    });

    test('crosses a year end', () {
      expect(lastMonths(DateTime(2026, 2), 4), [
        DateTime(2025, 11),
        DateTime(2025, 12),
        DateTime(2026, 1),
        DateTime(2026, 2),
      ]);
    });

    test('one month is just that month', () {
      expect(lastMonths(DateTime(2026, 10, 31), 1), [DateTime(2026, 10)]);
    });
  });

  group('yearRange', () {
    test('is the whole calendar year, the end not included', () {
      final range = yearRange(2026);

      expect(range.start, DateTime(2026));
      expect(range.end, DateTime(2027));
    });
  });

  group('previousPeriod of a year', () {
    test('a whole calendar year is compared with the year before', () {
      final previous = previousPeriod(yearRange(2026));

      expect(previous.start, DateTime(2025));
      expect(previous.end, DateTime(2026));
    });

    test('also after a leap year, which has a day more', () {
      final previous = previousPeriod(yearRange(2025));

      expect(previous, yearRange(2024));
      expect(daysBetween(previous.start, previous.end), 366);
    });

    test('a range that only starts on 1 January is not a year', () {
      final range = (start: DateTime(2026), end: DateTime(2026, 7));

      final previous = previousPeriod(range);

      expect(previous.end, DateTime(2026));
      expect(previous.start, isNot(DateTime(2025)));
    });
  });

  group('previousPeriod', () {
    test('a whole month is compared with the month before', () {
      final previous = previousPeriod(monthRange(DateTime(2026, 10)));
      expect(previous.start, DateTime(2026, 9));
      expect(previous.end, DateTime(2026, 10));
    });

    test('January is compared with December', () {
      final previous = previousPeriod(monthRange(DateTime(2026, 1)));
      expect(previous.start, DateTime(2025, 12));
      expect(previous.end, DateTime(2026, 1));
    });

    test(
      'any other range is compared with the same number of days before it',
      () {
        // 5 to 9 Oct (end is the 10th): 5 days, so 30 Sep to 4 Oct.
        final previous = previousPeriod((
          start: DateTime(2026, 10, 5),
          end: DateTime(2026, 10, 10),
        ));
        expect(previous.start, DateTime(2026, 9, 30));
        expect(previous.end, DateTime(2026, 10, 5));
      },
    );

    test('a single day is compared with the day before', () {
      final previous = previousPeriod((
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 6),
      ));
      expect(previous.start, DateTime(2026, 10, 4));
      expect(previous.end, DateTime(2026, 10, 5));
    });

    test('part of a month is not mistaken for a whole month', () {
      final previous = previousPeriod((
        start: DateTime(2026, 10),
        end: DateTime(2026, 10, 16),
      ));
      // 15 days before 1 Oct.
      expect(previous.start, DateTime(2026, 9, 16));
      expect(previous.end, DateTime(2026, 10));
    });
  });
}
