import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';

void main() {
  test('adds up what was marked', () {
    final s = FeelingSummary.of({
      Feeling.need: 1000,
      Feeling.want: 500,
      Feeling.regret: 250,
    });

    expect(s.total, 1750);
    expect(s.isEmpty, isFalse);
    expect(s.regretShare, closeTo(250 / 1750, 1e-9));
  });

  test('is empty when nothing was marked', () {
    final s = FeelingSummary.of(const {});
    expect(s.isEmpty, isTrue);
    expect(s.regretShare, 0);
  });

  test('counts the days since the last regret', () {
    final s = FeelingSummary.of(const {
      Feeling.regret: 1,
    }, lastRegret: DateTime(2026, 10, 5));

    expect(s.daysSinceRegret(DateTime(2026, 10, 11, 23)), 6);
    expect(s.daysSinceRegret(DateTime(2026, 10, 5)), 0);
    expect(
      const FeelingSummary().daysSinceRegret(DateTime(2026, 10, 5)),
      isNull,
    );
  });

  group('what Takka says', () {
    test('is proud when there is no regret', () {
      final s = FeelingSummary.of({Feeling.need: 1000});
      expect(regretLine(s, '৳0.00'), 'No regrets this month. Takka is proud!');
    });

    test('is worried when a third or more is regret', () {
      final s = FeelingSummary.of({Feeling.need: 600, Feeling.regret: 400});
      expect(regretLine(s, '৳4.00'), startsWith('A lot of regret'));
    });

    test('names the amount for a little regret', () {
      final s = FeelingSummary.of({Feeling.need: 9000, Feeling.regret: 100});
      expect(regretLine(s, '৳1.00'), startsWith('৳1.00 went on things'));
    });
  });
}
