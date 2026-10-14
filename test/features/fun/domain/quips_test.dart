import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/fun/domain/quips.dart';
import 'package:hishab/features/fun/domain/takka_mood.dart';

// Monday 12 October 2026, midday, 20 days into the month: nothing special.
final plain = DateTime(2026, 10, 12, 12);

QuipInputs inputs({
  DateTime? now,
  int overdrawn = 0,
  int? percent,
  int spentToday = 5000,
}) => QuipInputs(
  now: now ?? plain,
  overdrawnCount: overdrawn,
  budgetPercent: percent,
  spentToday: spentToday,
);

void main() {
  group('what Takka talks about', () {
    test('an account below zero comes first, with a worried face', () {
      final quip = pickQuip(inputs(overdrawn: 1, percent: 120));

      expect(quip.mood, TakkaMood.worried);
      expect(
        quip.text,
        anyOf(
          'Oops, an account is below zero. Did a payment go missing?',
          'Pocket says "ekhon taka nai!" Check the entries.',
          'Below zero? Either a bill ate it or an entry is missing.',
        ),
      );
    });

    test('a crossed budget is worried too', () {
      final quip = pickQuip(inputs(percent: 100));

      expect(quip.mood, TakkaMood.worried);
      expect(
        quip.text,
        contains(RegExp('budget|limit|Budget', caseSensitive: false)),
      );
    });

    test('a budget nearly used is worried, but not yet "crossed"', () {
      final near = pickQuip(inputs(percent: 90));
      final over = pickQuip(inputs(percent: 100));

      expect(near.mood, TakkaMood.worried);
      expect(near.text, isNot(over.text));
    });

    test('a budget that is fine says nothing about it', () {
      expect(pickQuip(inputs(percent: 40)).mood, TakkaMood.happy);
      expect(pickQuip(inputs()).mood, TakkaMood.happy);
    });

    test('late at night Takka is sleepy', () {
      for (final hour in [23, 0, 3]) {
        final quip = pickQuip(inputs(now: DateTime(2026, 10, 12, hour)));
        expect(quip.mood, TakkaMood.sleepy, reason: '$hour');
      }
      expect(
        pickQuip(inputs(now: DateTime(2026, 10, 12, 4))).mood,
        isNot(TakkaMood.sleepy),
      );
    });

    test('at the end of the month the pocket is going thon-thon', () {
      final quip = pickQuip(inputs(now: DateTime(2026, 10, 27, 12)));

      expect(quip.mood, TakkaMood.worried);
    });

    test('on a Friday Takka thinks of biryani', () {
      final friday = DateTime(2026, 10, 16, 12);
      final quip = pickQuip(inputs(now: friday));

      expect(quip.mood, TakkaMood.happy);
      expect(quip.text, contains(RegExp('Friday|Jummah')));
    });

    test('a quiet day, with nothing spent, is noticed', () {
      final quip = pickQuip(inputs(spentToday: 0));

      expect(quip.text, contains('today'));
    });

    test('otherwise it says something general', () {
      final quip = pickQuip(inputs());

      expect(allQuips, contains(quip.text));
      expect(quip.mood, TakkaMood.happy);
    });

    test('money trouble beats the time of day and the week', () {
      final lateFriday = DateTime(2026, 10, 16, 23, 30);

      expect(
        pickQuip(inputs(now: lateFriday, overdrawn: 2)).mood,
        TakkaMood.worried,
      );
    });
  });

  group('which line', () {
    test('is the same all day and changes the next day', () {
      final morning = pickQuip(inputs(now: DateTime(2026, 10, 12, 8)));
      final evening = pickQuip(inputs(now: DateTime(2026, 10, 12, 20)));
      final nextDay = pickQuip(inputs(now: DateTime(2026, 10, 13, 8)));

      expect(morning.text, evening.text);
      expect(nextDay.text, isNot(morning.text));
    });

    test('moves on to the next line with a nudge, and comes round again', () {
      final seen = <String>{
        for (var nudge = 0; nudge < 12; nudge++)
          pickQuip(inputs(), nudge: nudge).text,
      };

      expect(seen.length, greaterThan(1));
      expect(
        pickQuip(inputs(), nudge: 0).text,
        pickQuip(inputs(), nudge: 12).text,
      );
    });
  });

  test('every line is different and not empty', () {
    expect(allQuips.toSet(), hasLength(allQuips.length));
    expect(allQuips, everyElement(isNotEmpty));
  });
}
