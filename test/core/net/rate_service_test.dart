import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/net/rate_service.dart';

void main() {
  group('parseUsdToBdt', () {
    test('reads the taka rate', () {
      expect(
        parseUsdToBdt({
          'result': 'success',
          'rates': {'USD': 1, 'BDT': 123.198998},
        }),
        closeTo(123.199, 0.0001),
      );
    });

    test('reads a whole number rate', () {
      expect(
        parseUsdToBdt({
          'rates': {'BDT': 122},
        }),
        122.0,
      );
    });

    test('refuses an answer without the taka', () {
      expect(() => parseUsdToBdt({'rates': {}}), throwsA(isA<RateException>()));
      expect(() => parseUsdToBdt({'rates': 3}), throwsA(isA<RateException>()));
      expect(() => parseUsdToBdt(null), throwsA(isA<RateException>()));
      expect(() => parseUsdToBdt('x'), throwsA(isA<RateException>()));
    });

    test('refuses a rate that is not above zero', () {
      expect(
        () => parseUsdToBdt({
          'rates': {'BDT': 0},
        }),
        throwsA(isA<RateException>()),
      );
    });
  });

  group('parseMetalPrice', () {
    test('reads the price', () {
      expect(
        parseMetalPrice({'name': 'Silver', 'price': 59.417, 'symbol': 'XAG'}),
        59.417,
      );
    });

    test('refuses an answer without a price', () {
      expect(() => parseMetalPrice({}), throwsA(isA<RateException>()));
      expect(
        () => parseMetalPrice({'price': 'x'}),
        throwsA(isA<RateException>()),
      );
      expect(
        () => parseMetalPrice({'price': -1}),
        throwsA(isA<RateException>()),
      );
      expect(() => parseMetalPrice([]), throwsA(isA<RateException>()));
    });
  });

  test('a rate error shows its message', () {
    expect(const RateException('No net').toString(), 'No net');
  });
}
