import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/date_labels.dart';

void main() {
  final now = DateTime(2026, 10, 11, 14, 30); // a Sunday

  test('monthLabel is the month name and year', () {
    expect(monthLabel(DateTime(2026, 10)), 'October 2026');
    expect(monthLabel(DateTime(2027, 1, 31)), 'January 2027');
  });

  group('dayLabel', () {
    test('says Today and Yesterday', () {
      expect(dayLabel(DateTime(2026, 10, 11), now), 'Today');
      expect(dayLabel(DateTime(2026, 10, 10), now), 'Yesterday');
    });

    test('ignores the time of day', () {
      expect(dayLabel(DateTime(2026, 10, 11, 23, 59), now), 'Today');
      expect(dayLabel(DateTime(2026, 10, 10, 0, 1), now), 'Yesterday');
    });

    test('Yesterday works across a month and a year boundary', () {
      expect(
        dayLabel(DateTime(2026, 9, 30), DateTime(2026, 10, 1, 8)),
        'Yesterday',
      );
      expect(
        dayLabel(DateTime(2025, 12, 31), DateTime(2026, 1, 1, 8)),
        'Yesterday',
      );
    });

    test('shows the weekday and date for older days', () {
      expect(dayLabel(DateTime(2026, 10, 9), now), 'Fri, 9 Oct');
      expect(dayLabel(DateTime(2026, 1, 1), now), 'Thu, 1 Jan');
    });

    test('adds the year when it is not the current year', () {
      expect(dayLabel(DateTime(2025, 10, 9), now), 'Thu, 9 Oct 2025');
    });

    test('a day after today is shown as a date, not Today', () {
      expect(dayLabel(DateTime(2026, 10, 12), now), 'Mon, 12 Oct');
    });
  });

  group('rangeLabel', () {
    test('shows the last day, not the day after it', () {
      final range = (start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 10));
      expect(rangeLabel(range), '5 Oct 2026 – 9 Oct 2026');
    });

    test('a single day', () {
      final range = (start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 6));
      expect(rangeLabel(range), '5 Oct 2026 – 5 Oct 2026');
    });

    test('reaches back over a month end', () {
      final range = (start: DateTime(2026, 9, 25), end: DateTime(2026, 11));
      expect(rangeLabel(range), '25 Sep 2026 – 31 Oct 2026');
    });
  });
}
