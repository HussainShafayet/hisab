import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

RecurringRule rule({
  int id = 1,
  RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  DateTime? start,
  DateTime? nextDue,
  DateTime? endDate,
  bool autoAdd = false,
  bool remind = true,
  bool paused = false,
}) {
  final first = start ?? DateTime(2026, 8, 5);
  return RecurringRule(
    id: id,
    title: 'Rent',
    type: TransactionType.expense,
    amount: 1500000,
    accountId: 1,
    categoryId: 1,
    frequency: frequency,
    startDate: first,
    nextDue: nextDue ?? first,
    endDate: endDate,
    autoAdd: autoAdd,
    remind: remind,
    isPaused: paused,
  );
}

// Sunday 11 October 2026.
final today = DateTime(2026, 10, 11, 14, 30);

void main() {
  group('nextOccurrence', () {
    test('weekly is seven days later, across months', () {
      final next = nextOccurrence(
        DateTime(2026, 10, 28),
        RecurrenceFrequency.weekly,
        DateTime(2026, 10, 7),
      );

      expect(next, DateTime(2026, 11, 4));
    });

    test('monthly keeps the day of the month', () {
      final next = nextOccurrence(
        DateTime(2026, 10, 5),
        RecurrenceFrequency.monthly,
        DateTime(2026, 8, 5),
      );

      expect(next, DateTime(2026, 11, 5));
    });

    test('monthly goes into the next year in December', () {
      final next = nextOccurrence(
        DateTime(2026, 12, 15),
        RecurrenceFrequency.monthly,
        DateTime(2026, 1, 15),
      );

      expect(next, DateTime(2027, 1, 15));
    });

    test(
      'monthly uses the last day of a shorter month and then comes back',
      () {
        final anchor = DateTime(2026, 1, 31);

        final february = nextOccurrence(
          DateTime(2026, 1, 31),
          RecurrenceFrequency.monthly,
          anchor,
        );
        final march = nextOccurrence(
          february,
          RecurrenceFrequency.monthly,
          anchor,
        );
        final april = nextOccurrence(
          march,
          RecurrenceFrequency.monthly,
          anchor,
        );

        expect(february, DateTime(2026, 2, 28));
        expect(march, DateTime(2026, 3, 31));
        expect(april, DateTime(2026, 4, 30));
      },
    );

    test('monthly handles a leap year', () {
      final next = nextOccurrence(
        DateTime(2028, 1, 31),
        RecurrenceFrequency.monthly,
        DateTime(2028, 1, 31),
      );

      expect(next, DateTime(2028, 2, 29));
    });

    test('yearly keeps the month and day', () {
      final next = nextOccurrence(
        DateTime(2026, 3, 20),
        RecurrenceFrequency.yearly,
        DateTime(2025, 3, 20),
      );

      expect(next, DateTime(2027, 3, 20));
    });

    test('yearly uses the 28th for 29 February in a year without one', () {
      final anchor = DateTime(2024, 2, 29);

      final y2025 = nextOccurrence(anchor, RecurrenceFrequency.yearly, anchor);
      final y2028 = nextOccurrence(
        DateTime(2027, 2, 28),
        RecurrenceFrequency.yearly,
        anchor,
      );

      expect(y2025, DateTime(2025, 2, 28));
      expect(y2028, DateTime(2028, 2, 29));
    });
  });

  group('RecurringRule', () {
    test('is active unless it is paused or has ended', () {
      expect(rule().isActive, isTrue);
      expect(rule(paused: true).isActive, isFalse);
      expect(
        rule(
          nextDue: DateTime(2026, 11, 5),
          endDate: DateTime(2026, 10, 31),
        ).isActive,
        isFalse,
      );
    });

    test('has ended only when the next day is after the end', () {
      expect(
        rule(
          nextDue: DateTime(2026, 10, 31),
          endDate: DateTime(2026, 10, 31),
        ).isFinished,
        isFalse,
      );
      expect(
        rule(
          nextDue: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 10, 31),
        ).isFinished,
        isTrue,
      );
      expect(rule().isFinished, isFalse);
    });
  });

  group('dueDates', () {
    test('lists every day from the next due one up to today', () {
      final dates = dueDates(rule(), today);

      expect(dates, [
        DateTime(2026, 8, 5),
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 5),
      ]);
    });

    test('includes today, and nothing after it', () {
      expect(dueDates(rule(nextDue: DateTime(2026, 10, 11)), today), [
        DateTime(2026, 10, 11),
      ]);
      expect(dueDates(rule(nextDue: DateTime(2026, 10, 12)), today), isEmpty);
    });

    test('stops at the end day', () {
      final dates = dueDates(rule(endDate: DateTime(2026, 9, 5)), today);

      expect(dates, [DateTime(2026, 8, 5), DateTime(2026, 9, 5)]);
    });

    test('is limited, so a very old rule cannot make endless transactions', () {
      final weekly = rule(
        frequency: RecurrenceFrequency.weekly,
        start: DateTime(2020, 1, 1),
      );

      expect(dueDates(weekly, today).length, 60);
      expect(dueDates(weekly, today, limit: 5).length, 5);
    });
  });

  group('dueItemsOf', () {
    test('has one item per rule, with the oldest day and how many more', () {
      final items = dueItemsOf([rule()], today);

      expect(items.single.due, DateTime(2026, 8, 5));
      expect(items.single.more, 2);
    });

    test('leaves out rules that are not due yet and paused ones', () {
      final items = dueItemsOf([
        rule(id: 1, nextDue: DateTime(2026, 11, 5)),
        rule(id: 2, paused: true),
        rule(id: 3, nextDue: DateTime(2026, 10, 11)),
      ], today);

      expect(items.map((i) => i.rule.id), [3]);
      expect(items.single.more, 0);
    });

    test('lists the oldest first, then by id', () {
      final items = dueItemsOf([
        rule(id: 3, nextDue: DateTime(2026, 10, 9)),
        rule(id: 1, nextDue: DateTime(2026, 10, 9)),
        rule(id: 2, nextDue: DateTime(2026, 10, 1)),
      ], today);

      expect(items.map((i) => i.rule.id), [2, 1, 3]);
    });
  });

  group('upcomingReminders', () {
    test('has the next days of a rule, from today on', () {
      final planned = upcomingReminders([
        rule(start: DateTime(2026, 8, 15), nextDue: DateTime(2026, 10, 15)),
      ], today);

      expect(planned.map((p) => p.day), [
        DateTime(2026, 10, 15),
        DateTime(2026, 11, 15),
        DateTime(2026, 12, 15),
      ]);
      expect(planned.map((p) => p.index), [0, 1, 2]);
    });

    test('skips the days that are already past', () {
      final planned = upcomingReminders([rule()], today);

      // 5 Aug, 5 Sep and 5 Oct are past: they are in the due list.
      expect(planned.first.day, DateTime(2026, 11, 5));
    });

    test('includes today', () {
      final planned = upcomingReminders([
        rule(nextDue: DateTime(2026, 10, 11)),
      ], today);

      expect(planned.first.day, DateTime(2026, 10, 11));
    });

    test('stops at the end day', () {
      final planned = upcomingReminders([
        rule(
          start: DateTime(2026, 8, 15),
          nextDue: DateTime(2026, 10, 15),
          endDate: DateTime(2026, 11, 20),
        ),
      ], today);

      expect(planned.map((p) => p.day), [
        DateTime(2026, 10, 15),
        DateTime(2026, 11, 15),
      ]);
    });

    test(
      'leaves out rules that are paused, ended, add themselves or do not ask',
      () {
        final planned = upcomingReminders([
          rule(id: 1, nextDue: DateTime(2026, 10, 15), paused: true),
          rule(id: 2, nextDue: DateTime(2026, 10, 15), autoAdd: true),
          rule(id: 3, nextDue: DateTime(2026, 10, 15), remind: false),
          rule(
            id: 4,
            nextDue: DateTime(2026, 11, 15),
            endDate: DateTime(2026, 10, 31),
          ),
        ], today);

        expect(planned, isEmpty);
      },
    );

    test('mixes rules in order of day', () {
      final planned = upcomingReminders(
        [
          rule(id: 1, nextDue: DateTime(2026, 10, 20)),
          rule(id: 2, nextDue: DateTime(2026, 10, 12)),
        ],
        today,
        perRule: 1,
      );

      expect(planned.map((p) => p.rule.id), [2, 1]);
    });

    test('is limited to the most the phone can schedule', () {
      final rules = [
        for (var i = 1; i <= 30; i++)
          rule(id: i, nextDue: DateTime(2026, 10, 12 + i % 10)),
      ];

      expect(upcomingReminders(rules, today).length, 40);
      expect(upcomingReminders(rules, today, maxTotal: 5).length, 5);
    });
  });
}
