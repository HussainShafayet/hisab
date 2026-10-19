import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/metals/domain/metals.dart';

MetalHolding piece(
  Metal metal,
  int milligrams, {
  int purity = 917,
  int id = 1,
}) => MetalHolding(
  id: id,
  metal: metal,
  name: 'Piece $id',
  milligrams: milligrams,
  purity: purity,
  createdAt: DateTime(2026, 10, 15),
);

void main() {
  group('weights', () {
    test('a bhori is 11.664 grams', () {
      expect(milligramsFromBhori(bhori: 1), 11664);
      expect(milligramsFromBhori(ana: 16), 11664);
      expect(milligramsFromBhori(roti: 96), 11664);
    });

    test('an ana is 729 mg and a roti is 121.5 mg rounded up', () {
      expect(milligramsFromBhori(ana: 1), 729);
      expect(milligramsFromBhori(roti: 1), 122);
      expect(milligramsFromBhori(roti: 2), 243);
    });

    test('are written back as bhori, ana and roti', () {
      final w = bhoriWeightOf(milligramsFromBhori(bhori: 2, ana: 4, roti: 3));
      expect((w.bhori, w.ana, w.roti), (2, 4, 3));
    });

    test('carry into the next unit when a roti rounds up', () {
      final w = bhoriWeightOf(11664 - 20);
      expect((w.bhori, w.ana, w.roti), (1, 0, 0));
    });

    test('are shown in bhori and grams', () {
      expect(bhoriText(milligramsFromBhori(bhori: 1, ana: 8)), '1 bhori 8 ana');
      expect(gramText(25800), '25.80 g');
    });
  });

  group('value', () {
    test('pure gold is worth its weight times the price of a gram', () {
      expect(
        holdingValue(milligrams: 10000, purity: 1000, gramPrice: 1500000),
        15000000,
      );
    });

    test('22K gold is worth 91.7% of that', () {
      expect(
        holdingValue(milligrams: 11664, purity: 917, gramPrice: 1000000),
        (11664 * 917 * 1000000 + 500000) ~/ 1000000,
      );
    });

    test('a bhori price and a gram price turn into each other', () {
      const bhori = 18000000; // 180,000 taka for a bhori of 22K
      final gram = gramPriceFromBhori(Metal.gold, bhori);
      // The price of a gram is a whole number of poisha, and a bhori holds
      // about 10.7 grams of pure gold, so the round trip is off by up to
      // half a poisha for each of those grams.
      expect(bhoriPriceFromGram(Metal.gold, gram), closeTo(bhori, 6));
      // A 22K bhori is worth what the price says.
      expect(
        holdingValue(milligrams: 11664, purity: 917, gramPrice: gram),
        closeTo(bhori, 6),
      );
    });

    test('a silver bhori price is for pure silver', () {
      final gram = gramPriceFromBhori(Metal.silver, 1166400);
      expect(gram, 100000);
    });
  });

  group('totals', () {
    const prices = GramPrices(gold: 1000000, silver: 10000);

    test('add the pieces of each metal', () {
      final t = totalsOf([
        piece(Metal.gold, 10000, id: 1),
        piece(Metal.gold, 5000, purity: 1000, id: 2),
        piece(Metal.silver, 20000, purity: 1000, id: 3),
      ], prices);
      expect(t.gold.count, 2);
      expect(t.gold.milligrams, 15000);
      expect(t.gold.value, 9170000 + 5000000);
      expect(t.silver.value, 200000);
      expect(t.value, 9170000 + 5000000 + 200000);
    });

    test('count only a metal whose price is known', () {
      final t = totalsOf([
        piece(Metal.gold, 10000),
        piece(Metal.silver, 20000, purity: 1000, id: 2),
      ], const GramPrices(gold: 1000000));
      expect(t.silver.value, isNull);
      expect(t.value, t.gold.value);
    });

    test('an empty list is empty', () {
      expect(totalsOf(const [], prices).isEmpty, isTrue);
    });
  });

  group('the prices of a gram', () {
    test('are read from the settings, ignoring nonsense', () {
      final p = GramPrices.fromMap({
        'metals.gold_gram': '1500000',
        'metals.silver_gram': 'abc',
        'metals.prices_at': '2026-10-15T10:00:00.000',
      });
      expect(p.gold, 1500000);
      expect(p.silver, isNull);
      expect(p.at, DateTime(2026, 10, 15, 10));
    });

    test('are saved with a null for a missing one', () {
      expect(const GramPrices(gold: 5).toMap()['metals.silver_gram'], isNull);
    });
  });
}
