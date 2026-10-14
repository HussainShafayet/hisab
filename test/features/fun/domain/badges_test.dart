import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/fun/domain/badges.dart';

List<DateTime> oct(Iterable<int> days) => [
  for (final d in days) DateTime(2026, 10, d),
];

Map<DateTime, bool> logged(Iterable<int> days, {Set<int> spent = const {}}) => {
  for (final d in days) DateTime(2026, 10, d): spent.contains(d),
};

bool earned(BadgeReport r, BadgeId id) =>
    r.badges.singleWhere((b) => b.id == id).earned;

void main() {
  final today = DateTime(2026, 10, 11, 15);

  group('the writing streak', () {
    test('counts the days in a row ending today', () {
      expect(writingStreak(oct([9, 10, 11]), today), 3);
    });

    test('still counts when nothing is written yet today', () {
      expect(writingStreak(oct([8, 9, 10]), today), 3);
    });

    test('is broken by a day with nothing, and a gap before yesterday', () {
      expect(writingStreak(oct([5, 6, 9, 11]), today), 1);
      expect(writingStreak(oct([5, 6, 7]), today), 0);
      expect(writingStreak(const [], today), 0);
    });

    test('goes across a month end', () {
      final days = [
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 30),
        ...oct([1]),
      ];
      expect(writingStreak(days, DateTime(2026, 10, 1)), 3);
    });

    test('the best run is the longest ever', () {
      expect(bestWritingStreak(oct([1, 2, 3, 4, 8, 9, 11])), 4);
      expect(bestWritingStreak(const []), 0);
      expect(bestWritingStreak(oct([3, 3, 3])), 1);
    });
  });

  group('days with no spending', () {
    test('count the days since the first entry, up to yesterday', () {
      // Entries on 5 (spent), 6, 8 (spent): 7, 9 and 10 are free; today is not.
      final days = logged([5, 6, 8], spent: {5, 8});
      expect(spendFreeDays(days, today), 4); // 6, 7, 9, 10
    });

    test('count only from the given day', () {
      final days = {DateTime(2026, 9, 20): true, DateTime(2026, 10, 2): true};
      expect(spendFreeDays(days, today, from: DateTime(2026, 10, 1)), 9);
    });

    test('are zero without any entry', () {
      expect(spendFreeDays(const {}, today), 0);
    });
  });

  group('badges', () {
    test('a new user has none', () {
      final r = badgeReportOf(const ActivityFacts(), today);
      expect(r.earned, 0);
      expect(r.streak, 0);
    });

    test('the first entry and a streak', () {
      final r = badgeReportOf(
        ActivityFacts(days: logged([9, 10, 11], spent: {9, 10, 11})),
        today,
      );
      expect(earned(r, BadgeId.firstEntry), isTrue);
      expect(earned(r, BadgeId.streak3), isTrue);
      expect(earned(r, BadgeId.streak7), isFalse);
      expect(earned(r, BadgeId.spendFreeDay), isFalse);
      expect(r.streak, 3);
    });

    test('a streak badge is kept after the streak ends', () {
      final r = badgeReportOf(
        ActivityFacts(days: logged([1, 2, 3, 4, 5, 6, 7])),
        today,
      );
      expect(earned(r, BadgeId.streak7), isTrue);
      expect(r.streak, 0);
      expect(r.bestStreak, 7);
    });

    test('a spend-free day', () {
      final r = badgeReportOf(
        ActivityFacts(days: logged([8, 10], spent: {8, 10})),
        today,
      );
      expect(earned(r, BadgeId.spendFreeDay), isTrue); // 9
      expect(r.spendFreeThisMonth, 1);
    });

    test('honest with myself, and a clear mind', () {
      var r = badgeReportOf(
        ActivityFacts(
          days: logged([10]),
          markedExpenses: 5,
          lastRegret: DateTime(2026, 10, 8),
        ),
        today,
      );
      expect(earned(r, BadgeId.selfAware), isTrue);
      expect(earned(r, BadgeId.regretFreeWeek), isFalse);

      r = badgeReportOf(
        ActivityFacts(
          days: logged([10]),
          markedExpenses: 5,
          lastRegret: DateTime(2026, 10, 4),
        ),
        today,
      );
      expect(earned(r, BadgeId.regretFreeWeek), isTrue);

      r = badgeReportOf(
        ActivityFacts(days: logged([10]), markedExpenses: 4),
        today,
      );
      expect(earned(r, BadgeId.selfAware), isFalse);
      expect(earned(r, BadgeId.regretFreeWeek), isFalse);
    });

    test('goals, loans and gold', () {
      final r = badgeReportOf(
        const ActivityFacts(
          goalReached: true,
          loanSettled: true,
          hasMetals: true,
        ),
        today,
      );
      expect(earned(r, BadgeId.goalReached), isTrue);
      expect(earned(r, BadgeId.loanSettled), isTrue);
      expect(earned(r, BadgeId.goldKeeper), isTrue);
    });

    test('every badge has a name and a way to win it', () {
      for (final id in BadgeId.values) {
        expect(badgeTitle(id), isNotEmpty);
        expect(badgeHowTo(id), isNotEmpty);
      }
    });
  });
}
