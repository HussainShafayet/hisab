import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/fun/domain/wrapped.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';

void main() {
  group('when the wrapped is on offer', () {
    test('in the last four days of a month, for that month', () {
      expect(wrappedMonthFor(DateTime(2026, 10, 27)), DateTime(2026, 10));
      expect(wrappedMonthFor(DateTime(2026, 10, 31)), DateTime(2026, 10));
      expect(wrappedMonthFor(DateTime(2026, 2, 25)), DateTime(2026, 2));
    });

    test('in the first five days, for the month before', () {
      expect(wrappedMonthFor(DateTime(2026, 11, 1)), DateTime(2026, 10));
      expect(wrappedMonthFor(DateTime(2026, 11, 5)), DateTime(2026, 10));
      expect(wrappedMonthFor(DateTime(2027, 1, 2)), DateTime(2026, 12));
    });

    test('not in the middle of a month', () {
      expect(wrappedMonthFor(DateTime(2026, 10, 6)), isNull);
      expect(wrappedMonthFor(DateTime(2026, 10, 26)), isNull);
      expect(wrappedMonthFor(DateTime(2026, 10, 11)), isNull);
    });
  });

  group('the persona', () {
    test('comes from the top category', () {
      expect(wrappedPersona('Food'), 'The Foodie');
      expect(wrappedPersona('Transport'), 'The Traveller');
      expect(wrappedPersona('Bills & utilities'), 'The Responsible One');
      expect(wrappedPersona('Family & gifts'), 'The Generous One');
    });

    test('is balanced when nothing fits', () {
      expect(wrappedPersona('Something else'), 'The Balanced One');
      expect(wrappedPersona(null), 'The Balanced One');
    });
  });

  test('the month in numbers', () {
    final w = MonthWrapped(
      month: DateTime(2026, 10),
      income: 5000000,
      expense: 3000000,
      entries: 20,
      spendFreeDays: 4,
      feelings: const FeelingSummary(),
      topCategory: 'Food',
      topCategoryAmount: 1200000,
    );

    expect(w.saved, 2000000);
    expect(w.topShare, closeTo(0.4, 1e-9));
    expect(w.isEmpty, isFalse);
  });

  test('a month with no entries is empty and has no share', () {
    final w = MonthWrapped(
      month: DateTime(2026, 10),
      income: 0,
      expense: 0,
      entries: 0,
      spendFreeDays: 0,
      feelings: const FeelingSummary(),
    );

    expect(w.isEmpty, isTrue);
    expect(w.topShare, 0);
  });
}
