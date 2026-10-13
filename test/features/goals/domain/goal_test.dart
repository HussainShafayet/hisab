import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/goals/domain/goal.dart';

// Sunday 11 October 2026.
final today = DateTime(2026, 10, 11, 14, 30);

GoalWithSaved goal({int target = 10000000, int saved = 0, DateTime? day}) =>
    GoalWithSaved(
      goal: SavingsGoal(
        id: 1,
        name: 'Laptop',
        target: target,
        targetDate: day,
        icon: 'laptop',
        createdAt: DateTime(2026, 9),
      ),
      saved: saved,
    );

void main() {
  group('progress', () {
    test('is what is saved of the target', () {
      final g = goal(saved: 2500000);

      expect(g.left, 7500000);
      expect(g.fraction, 0.25);
      expect(g.isReached, isFalse);
    });

    test('is reached at the target, and goes no further than full', () {
      final g = goal(saved: 12000000);

      expect(g.isReached, isTrue);
      expect(g.left, 0);
      expect(g.fraction, 1.0);
    });

    test('starts at nothing', () {
      expect(goal().fraction, 0.0);
      expect(goal().isReached, isFalse);
    });
  });

  group('the day', () {
    test('counts the days left', () {
      expect(goal(day: DateTime(2026, 10, 21)).daysLeft(today), 10);
      expect(goal(day: DateTime(2026, 10, 11)).daysLeft(today), 0);
      expect(goal().daysLeft(today), isNull);
    });

    test('is late once it has passed without reaching the target', () {
      expect(goal(day: DateTime(2026, 10, 10)).isLate(today), isTrue);
      expect(goal(day: DateTime(2026, 10, 11)).isLate(today), isFalse);
      expect(
        goal(saved: 10000000, day: DateTime(2026, 10, 10)).isLate(today),
        isFalse,
      );
      expect(goal().isLate(today), isFalse);
    });
  });

  group('what to put aside', () {
    test('is spread over the months left, rounded up', () {
      // ৳100,000 target, ৳40,000 saved, 90 days (3 months): ৳20,000 a month.
      final g = goal(saved: 4000000, day: DateTime(2027, 1, 9));

      expect(g.daysLeft(today), 90);
      expect(g.perMonth(today), 2000000);
    });

    test('rounds a part month up to a whole one', () {
      // 31 days is two months of 30 days.
      final g = goal(target: 1000001, day: DateTime(2026, 11, 11));

      expect(g.daysLeft(today), 31);
      expect(g.perMonth(today), 500001);
    });

    test('is everything that is left when the day is under a month away', () {
      final g = goal(saved: 9000000, day: DateTime(2026, 10, 25));

      expect(g.perMonth(today), 1000000);
    });

    test('is spread over the weeks left', () {
      // 14 days: two weeks.
      final g = goal(saved: 9000000, day: DateTime(2026, 10, 25));

      expect(g.perWeek(today), 500000);
    });

    test('is nothing without a day, after it, or once reached', () {
      expect(goal().perMonth(today), isNull);
      expect(goal(day: DateTime(2026, 10, 1)).perMonth(today), isNull);
      expect(goal(day: DateTime(2026, 10, 11)).perMonth(today), isNull);
      expect(
        goal(saved: 10000000, day: DateTime(2027, 1, 1)).perWeek(today),
        isNull,
      );
    });
  });

  group('all goals', () {
    test('add up what is saved and what is wanted', () {
      final goals = [
        goal(saved: 100, target: 1000),
        goal(saved: 2000, target: 1500),
      ];

      expect(totalSaved(goals), 2100);
      expect(totalTarget(goals), 2500);
    });
  });
}
