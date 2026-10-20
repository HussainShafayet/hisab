import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';

// A week, Sunday 11 to Saturday 17 October 2026.
final start = DateTime(2026, 10, 11);
final end = DateTime(2026, 10, 17);

ChallengeItem item({
  int spent = 0,
  int limit = 0,
  ChallengeKind kind = ChallengeKind.noSpend,
  String? categoryName,
}) => ChallengeItem(
  challenge: Challenge(
    id: 1,
    title: 'Test',
    kind: kind,
    limit: limit,
    startDate: start,
    endDate: end,
    createdAt: DateTime(2026, 10, 10),
    categoryId: categoryName == null ? null : 5,
  ),
  spent: spent,
  categoryName: categoryName,
);

void main() {
  group('Challenge', () {
    test('counts its days with both ends', () {
      expect(item().challenge.days, 7);
    });

    test('a single day lasts one day', () {
      final one = Challenge(
        id: 1,
        title: 'x',
        kind: ChallengeKind.noSpend,
        limit: 0,
        startDate: start,
        endDate: start,
        createdAt: start,
      );
      expect(one.days, 1);
    });
  });

  group('the state of a challenge', () {
    test('is upcoming before its first day', () {
      expect(
        item().stateOn(DateTime(2026, 10, 10, 23)),
        ChallengeState.upcoming,
      );
    });

    test('is active on its first and its last day', () {
      expect(
        item().stateOn(DateTime(2026, 10, 11, 0, 5)),
        ChallengeState.active,
      );
      expect(item().stateOn(DateTime(2026, 10, 17, 23)), ChallengeState.active);
    });

    test('is won once it is over with nothing broken', () {
      expect(item().stateOn(DateTime(2026, 10, 18)), ChallengeState.won);
    });

    test('is broken as soon as a no-spend challenge sees spending', () {
      expect(
        item(spent: 100).stateOn(DateTime(2026, 10, 12)),
        ChallengeState.broken,
      );
      expect(
        item(spent: 100).stateOn(DateTime(2026, 10, 20)),
        ChallengeState.broken,
      );
    });

    test('is active up to the limit and broken above it', () {
      final under = item(kind: ChallengeKind.limit, limit: 50000, spent: 50000);
      final over = item(kind: ChallengeKind.limit, limit: 50000, spent: 50001);

      expect(under.stateOn(DateTime(2026, 10, 14)), ChallengeState.active);
      expect(under.stateOn(DateTime(2026, 10, 18)), ChallengeState.won);
      expect(over.stateOn(DateTime(2026, 10, 14)), ChallengeState.broken);
    });
  });

  group('progress', () {
    test('remaining is the limit less the spending, never below zero', () {
      expect(
        item(kind: ChallengeKind.limit, limit: 50000, spent: 20000).remaining,
        30000,
      );
      expect(
        item(kind: ChallengeKind.limit, limit: 50000, spent: 70000).remaining,
        0,
      );
    });

    test('the fraction runs from 0 to 1', () {
      expect(
        item(kind: ChallengeKind.limit, limit: 50000, spent: 12500).fraction,
        0.25,
      );
      expect(
        item(kind: ChallengeKind.limit, limit: 50000, spent: 90000).fraction,
        1,
      );
      expect(item().fraction, 0);
      expect(item(spent: 1).fraction, 1);
    });

    test('the day number and the days left follow today', () {
      final c = item();
      expect(c.dayNumber(DateTime(2026, 10, 11)), 1);
      expect(c.dayNumber(DateTime(2026, 10, 14, 15)), 4);
      expect(c.dayNumber(DateTime(2026, 10, 30)), 7);
      expect(c.dayNumber(DateTime(2026, 10, 1)), 1);

      expect(c.daysLeft(DateTime(2026, 10, 11)), 7);
      expect(c.daysLeft(DateTime(2026, 10, 17)), 1);
      expect(c.daysLeft(DateTime(2026, 10, 18)), 0);
    });

    test('days until the start', () {
      final c = item();
      expect(c.daysUntilStart(DateTime(2026, 10, 8)), 3);
      expect(c.daysUntilStart(DateTime(2026, 10, 11)), 0);
      expect(c.daysUntilStart(DateTime(2026, 10, 15)), 0);
    });
  });

  group('challengeTitle', () {
    test('names a no-spend challenge', () {
      expect(
        challengeTitle(kind: ChallengeKind.noSpend, days: 7, limit: 0),
        'No spending for 7 days',
      );
      expect(
        challengeTitle(kind: ChallengeKind.noSpend, days: 1, limit: 0),
        'No spending for 1 day',
      );
    });

    test('names a no-spend challenge about a category', () {
      expect(
        challengeTitle(
          kind: ChallengeKind.noSpend,
          days: 7,
          limit: 0,
          categoryName: 'Rickshaw',
        ),
        'No Rickshaw spending for 7 days',
      );
    });

    test('names a limit challenge, with and without a category', () {
      expect(
        challengeTitle(kind: ChallengeKind.limit, days: 30, limit: 500000),
        'Spend under ৳5,000.00 in 30 days',
      );
      expect(
        challengeTitle(
          kind: ChallengeKind.limit,
          days: 7,
          limit: 200000,
          categoryName: 'Bazar',
        ),
        'Bazar under ৳2,000.00 in 7 days',
      );
      expect(
        challengeTitle(kind: ChallengeKind.limit, days: 1, limit: 10000),
        'Spend under ৳100.00 in 1 day',
      );
    });
  });

  group('challengePresets', () {
    ChallengePreset preset(DateTime today, ChallengePresetId id) =>
        challengePresets(today).firstWhere((p) => p.id == id);

    test('a day and a week start today', () {
      final today = DateTime(2026, 10, 14, 16);

      expect(
        preset(today, ChallengePresetId.day).start,
        DateTime(2026, 10, 14),
      );
      expect(preset(today, ChallengePresetId.day).days, 1);
      expect(
        preset(today, ChallengePresetId.week).start,
        DateTime(2026, 10, 14),
      );
      expect(preset(today, ChallengePresetId.week).days, 7);
    });

    test('the weekend is the coming Friday and Saturday', () {
      // Wednesday 14 October 2026: Friday is the 16th.
      final monday = preset(DateTime(2026, 10, 12), ChallengePresetId.weekend);
      final wednesday = preset(
        DateTime(2026, 10, 14),
        ChallengePresetId.weekend,
      );
      final sunday = preset(DateTime(2026, 10, 18), ChallengePresetId.weekend);

      expect(monday.start, DateTime(2026, 10, 16));
      expect(wednesday.start, DateTime(2026, 10, 16));
      expect(sunday.start, DateTime(2026, 10, 23));
      expect([monday.days, wednesday.days, sunday.days], [2, 2, 2]);
    });

    test(
      'on a Friday the weekend starts today, on a Saturday it has a day left',
      () {
        final friday = preset(
          DateTime(2026, 10, 16),
          ChallengePresetId.weekend,
        );
        final saturday = preset(
          DateTime(2026, 10, 17),
          ChallengePresetId.weekend,
        );

        expect(friday.start, DateTime(2026, 10, 16));
        expect(friday.days, 2);
        expect(saturday.start, DateTime(2026, 10, 17));
        expect(saturday.days, 1);
      },
    );

    test('the rickshaw week names its category', () {
      final rickshaw = preset(
        DateTime(2026, 10, 14),
        ChallengePresetId.rickshawWeek,
      );

      expect(rickshaw.categoryName, 'Rickshaw');
      expect(rickshaw.days, 7);
      expect(
        challengePresets(DateTime(2026, 10, 14))
            .where((p) => p.id != ChallengePresetId.rickshawWeek)
            .every((p) => p.categoryName == null),
        isTrue,
      );
    });

    test('every preset has a label', () {
      expect(challengePresets(DateTime(2026, 10, 14)).map((p) => p.label), [
        'No-spend day',
        'No-spend weekend',
        'No-spend week',
        'Rickshaw-free week',
      ]);
    });
  });
}
