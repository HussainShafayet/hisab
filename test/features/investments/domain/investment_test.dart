import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/investments/domain/investment.dart';

Investment base({int? value, bool closed = false}) => Investment(
  id: 1,
  name: 'Poultry farm',
  note: '',
  startedOn: DateTime(2026, 1, 1),
  isClosed: closed,
  currentValue: value,
);

InvestmentItem item({
  int putIn = 0,
  int profit = 0,
  int takenBack = 0,
  int? value,
  bool closed = false,
}) => InvestmentItem(
  investment: base(value: value, closed: closed),
  putIn: putIn,
  profit: profit,
  takenBack: takenBack,
);

void main() {
  group('an investment', () {
    test('with nothing in it has nothing', () {
      final i = item();

      expect(i.stillIn, 0);
      expect(i.value, 0);
      expect(i.totalReturn, 0);
      expect(i.roiPercent, isNull);
      expect(i.standing, InvestmentStanding.even);
    });

    test('with no value set is worth what it cost, so profit is the gain', () {
      final i = item(putIn: 1000000, profit: 150000);

      expect(i.stillIn, 1000000);
      expect(i.value, 1000000);
      expect(i.totalReturn, 150000);
      expect(i.roiPercent, 15);
      expect(i.standing, InvestmentStanding.gain);
    });

    test('takes the money taken back off what is still in', () {
      final i = item(putIn: 1000000, takenBack: 400000);

      expect(i.stillIn, 600000);
      expect(i.value, 600000);
      // Nothing was gained: 400000 came back and 600000 is still there.
      expect(i.totalReturn, 0);
    });

    test('goes by the value that was set, up or down', () {
      expect(item(putIn: 1000000, value: 1300000).totalReturn, 300000);
      expect(item(putIn: 1000000, value: 1300000).roiPercent, 30);
      expect(item(putIn: 1000000, value: 700000).totalReturn, -300000);
      expect(item(putIn: 1000000, value: 700000).roiPercent, -30);
      expect(
        item(putIn: 1000000, value: 700000).standing,
        InvestmentStanding.loss,
      );
    });

    test('adds profit received to the value for the return', () {
      final i = item(putIn: 1000000, profit: 200000, value: 900000);

      expect(i.totalReturn, 100000);
      expect(i.roiPercent, 10);
    });

    test('counts money taken back as part of the return', () {
      final i = item(
        putIn: 1000000,
        takenBack: 500000,
        profit: 100000,
        value: 600000,
      );

      // 100000 + 500000 + 600000 - 1000000.
      expect(i.totalReturn, 200000);
      expect(i.roiPercent, 20);
    });

    test('a closed one is worth nothing: what was not taken back is lost', () {
      final i = item(putIn: 1000000, takenBack: 300000, closed: true);

      expect(i.value, 0);
      expect(i.totalReturn, -700000);
      expect(i.standing, InvestmentStanding.loss);
    });

    test('a closed one that paid everything back with profit', () {
      final i = item(
        putIn: 1000000,
        takenBack: 1000000,
        profit: 250000,
        closed: true,
      );

      expect(i.stillIn, 0);
      expect(i.totalReturn, 250000);
    });

    test('ignores a value that was set once it is closed', () {
      expect(item(putIn: 100, value: 500, closed: true).value, 0);
    });

    test('can never take back more than is still in', () {
      expect(item(putIn: 1000, takenBack: 1500).stillIn, 0);
      expect(item(putIn: 1000, takenBack: 400).canTakeBack, 600);
    });

    test('rounds the percent half away from zero', () {
      // 1 of 8 is 12.5% -> 13; -1 of 8 is -12.5% -> -13.
      expect(item(putIn: 800, profit: 100).roiPercent, 13);
      expect(item(putIn: 800, value: 700).roiPercent, -13);
      // 1 of 3 is 33.3% -> 33.
      expect(item(putIn: 300, profit: 100).roiPercent, 33);
    });
  });

  group('the totals', () {
    test('add every investment up', () {
      final totals = investmentTotals([
        item(putIn: 1000000, profit: 100000),
        item(putIn: 500000, value: 400000),
        item(putIn: 200000, takenBack: 200000, profit: 50000, closed: true),
      ]);

      expect(totals.putIn, 1700000);
      expect(totals.profit, 150000);
      // Open ones at cost, a closed one has nothing still in.
      expect(totals.stillIn, 1500000);
      expect(totals.value, 1000000 + 400000);
      expect(totals.totalReturn, 100000 + -100000 + 50000);
    });

    test('have a percent of everything put in', () {
      final totals = investmentTotals([
        item(putIn: 1000000, profit: 100000),
        item(putIn: 1000000, profit: 300000),
      ]);

      expect(totals.roiPercent, 20);
    });

    test('are empty with no investments', () {
      final totals = investmentTotals(const []);

      expect(totals.putIn, 0);
      expect(totals.totalReturn, 0);
      expect(totals.roiPercent, isNull);
    });
  });
}
