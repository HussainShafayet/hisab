import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/insights/presentation/money_tips.dart';

void main() {
  test('there are enough tips and none repeats', () {
    final tips = moneyTips();
    expect(tips.length, greaterThanOrEqualTo(15));
    expect(tips.toSet(), hasLength(tips.length));
  });

  test('the tip changes with the day and moves on with skip', () {
    final monday = DateTime(2026, 10, 12);
    expect(tipOfTheDay(monday), isNot(tipOfTheDay(DateTime(2026, 10, 13))));
    expect(tipOfTheDay(monday, skip: 1), tipOfTheDay(DateTime(2026, 10, 13)));
  });

  test('the same day gives the same tip', () {
    expect(
      tipOfTheDay(DateTime(2026, 10, 12, 8)),
      tipOfTheDay(DateTime(2026, 10, 12, 22)),
    );
  });
}
