import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/zakat/domain/zakat.dart';

void main() {
  group('nisab', () {
    test('is 52.5 tola of silver or 7.5 tola of gold', () {
      expect(nisabHundredthsOfGram(NisabBasis.silver), 61236);
      expect(nisabHundredthsOfGram(NisabBasis.gold), 8748);
    });

    test('is worth the grams times the price of a gram', () {
      // ৳100 a gram: 612.36 g is ৳61,236.
      expect(nisabValue(NisabBasis.silver, 10000), 6123600);
      // ৳10,000 a gram: 87.48 g is ৳874,800.
      expect(nisabValue(NisabBasis.gold, 1000000), 87480000);
    });

    test('is unknown without a price', () {
      expect(nisabValue(NisabBasis.silver, null), isNull);
      expect(nisabValue(NisabBasis.silver, 0), isNull);
    });
  });

  group('gramPriceFrom', () {
    test('turns dollars an ounce into poisha a gram', () {
      // $60 an ounce at ৳120: ৳7,200 an ounce, ৳231.49 a gram.
      expect(gramPriceFrom(usdPerOunce: 60, bdtPerUsd: 120), 23149);
    });
  });

  group('calculateZakat', () {
    ZakatResult calc({
      int accounts = 10000000,
      int owed = 0,
      int other = 0,
      int debts = 0,
      int? nisab = 6123600,
    }) => calculateZakat(
      ZakatInput(
        accounts: accounts,
        owedToYou: owed,
        otherAssets: other,
        youOwe: debts,
        nisab: nisab,
      ),
    );

    test('is 2.5% of the wealth once it reaches the nisab', () {
      final result = calc();

      expect(result.net, 10000000);
      expect(result.isDue, isTrue);
      expect(result.due, 250000);
      expect(result.shortOfNisab, isNull);
    });

    test('rounds up to the next poisha', () {
      // 2.5% of 10,000,001 is 250,000.025.
      expect(calc(accounts: 10000001).due, 250001);
    });

    test('counts what others owe, other savings, and takes off debts', () {
      final result = calc(
        accounts: 5000000,
        owed: 2000000,
        other: 1500000,
        debts: 1000000,
      );

      expect(result.assets, 8500000);
      expect(result.liabilities, 1000000);
      expect(result.net, 7500000);
      expect(result.due, 187500);
    });

    test('is nothing under the nisab, and says how far under', () {
      final result = calc(accounts: 4000000);

      expect(result.isDue, isFalse);
      expect(result.due, 0);
      expect(result.shortOfNisab, 2123600);
    });

    test('is due exactly at the nisab', () {
      final result = calc(accounts: 6123600);

      expect(result.isDue, isTrue);
      expect(result.due, 153090);
    });

    test('never goes below zero when debts are bigger', () {
      final result = calc(accounts: 1000, debts: 5000);

      expect(result.net, 0);
      expect(result.due, 0);
    });

    test('says nothing without a nisab', () {
      final result = calc(nisab: null);

      expect(result.needsNisab, isTrue);
      expect(result.isDue, isFalse);
      expect(result.due, 0);
    });
  });

  group('nextZakatDay', () {
    final today = DateTime(2026, 10, 11, 14, 30);

    test('is this year while the day is still to come', () {
      expect(nextZakatDay(12, 1, today), DateTime(2026, 12, 1));
    });

    test('is today on the day', () {
      expect(nextZakatDay(10, 11, today), DateTime(2026, 10, 11));
    });

    test('is next year once the day has gone', () {
      expect(nextZakatDay(3, 20, today), DateTime(2027, 3, 20));
      expect(nextZakatDay(10, 10, today), DateTime(2027, 10, 10));
    });

    test('puts 29 February on the 28th in other years', () {
      expect(nextZakatDay(2, 29, today), DateTime(2027, 2, 28));
      expect(nextZakatDay(2, 29, DateTime(2027, 12, 1)), DateTime(2028, 2, 29));
    });
  });
}
