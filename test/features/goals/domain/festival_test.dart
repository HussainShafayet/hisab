import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:hishab/features/goals/domain/goal.dart';

GoalWithSaved goal(DateTime? day, {int saved = 0}) => GoalWithSaved(
  goal: SavingsGoal(
    id: 1,
    name: 'A goal',
    target: 5000000,
    icon: 'gift',
    createdAt: DateTime(2026, 10, 1),
    targetDate: day,
  ),
  saved: saved,
);

void main() {
  final today = DateTime(2026, 10, 11);

  group('the next day of a festival', () {
    test('Eid-ul-Fitr is in March 2027', () {
      expect(
        nextFestivalDate(Festival.eidUlFitr, today),
        DateTime(2027, 3, 10),
      );
    });

    test('Eid-ul-Adha is in May 2027', () {
      expect(
        nextFestivalDate(Festival.eidUlAdha, today),
        DateTime(2027, 5, 17),
      );
    });

    test('Pohela Boishakh is on 14 April', () {
      expect(
        nextFestivalDate(Festival.pohelaBoishakh, today),
        DateTime(2027, 4, 14),
      );
      expect(
        nextFestivalDate(Festival.pohelaBoishakh, DateTime(2026, 4, 14, 20)),
        DateTime(2026, 4, 14),
      );
      expect(
        nextFestivalDate(Festival.pohelaBoishakh, DateTime(2026, 4, 15)),
        DateTime(2027, 4, 14),
      );
    });

    test('today counts, tomorrow moves on to next year', () {
      final day = nextFestivalDate(Festival.eidUlAdha, DateTime(2026, 1, 1));
      expect(day, DateTime(2026, 5, 27));
      expect(nextFestivalDate(Festival.eidUlAdha, day), day);
      expect(
        nextFestivalDate(Festival.eidUlAdha, day.add(const Duration(days: 1))),
        DateTime(2027, 5, 17),
      );
    });

    test('is never in the past, over several years', () {
      for (var i = 0; i < 4000; i += 37) {
        final from = DateTime(2024).add(Duration(days: i));
        for (final f in Festival.values) {
          expect(nextFestivalDate(f, from).isBefore(from), isFalse);
        }
      }
    });

    test('the Eids are only estimated', () {
      expect(isEstimated(Festival.eidUlFitr), isTrue);
      expect(isEstimated(Festival.eidUlAdha), isTrue);
      expect(isEstimated(Festival.pohelaBoishakh), isFalse);
    });
  });

  test('a fund is named after the festival and the year', () {
    expect(
      festivalFundName(Festival.eidUlFitr, DateTime(2027, 3, 10)),
      'Eid-ul-Fitr 2027',
    );
  });

  group('upcoming festivals', () {
    test('come nearest first, with the days left', () {
      final list = upcomingFestivals(today, const []);

      expect(list.map((u) => u.festival), [
        Festival.eidUlFitr,
        Festival.pohelaBoishakh,
        Festival.eidUlAdha,
      ]);
      expect(list.first.daysLeft, 150);
      expect(list.every((u) => u.fund == null), isTrue);
    });

    test('find the goal whose day is within three days', () {
      final near = goal(DateTime(2027, 3, 11));
      final list = upcomingFestivals(today, [near]);

      expect(list.first.fund, same(near));
      expect(list[1].fund, isNull);
    });

    test('ignore a goal further away or with no day', () {
      final list = upcomingFestivals(today, [
        goal(DateTime(2027, 3, 20)),
        goal(null),
      ]);

      expect(list.every((u) => u.fund == null), isTrue);
    });
  });
}
