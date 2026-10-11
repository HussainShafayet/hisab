import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/money.dart';

void main() {
  group('formatPoisha', () {
    test('always shows two decimals', () {
      expect(formatPoisha(0), '৳0.00');
      expect(formatPoisha(5), '৳0.05');
      expect(formatPoisha(150000), '৳1,500.00');
      expect(formatPoisha(123456), '৳1,234.56');
    });

    test('groups digits the South Asian way (lakh, crore)', () {
      expect(formatPoisha(123456700), '৳12,34,567.00');
      expect(formatPoisha(12345678900), '৳12,34,56,789.00');
    });

    test('puts the minus sign before the symbol', () {
      expect(formatPoisha(-5), '-৳0.05');
      expect(formatPoisha(-123456), '-৳1,234.56');
    });

    test('can leave the symbol out', () {
      expect(formatPoisha(123456, symbol: false), '1,234.56');
      expect(formatPoisha(-100, symbol: false), '-1.00');
    });
  });

  group('parseTakaToPoisha', () {
    test('reads whole and decimal amounts', () {
      expect(parseTakaToPoisha('1500'), 150000);
      expect(parseTakaToPoisha('1500.5'), 150050);
      expect(parseTakaToPoisha('1500.55'), 150055);
      expect(parseTakaToPoisha('0.05'), 5);
      expect(parseTakaToPoisha('0'), 0);
    });

    test('ignores spaces, commas and the taka sign', () {
      expect(parseTakaToPoisha(' 1,500.50 '), 150050);
      expect(parseTakaToPoisha('৳ 100'), 10000);
      expect(parseTakaToPoisha('12,34,567'), 123456700);
    });

    test('reads negative amounts', () {
      expect(parseTakaToPoisha('-250.75'), -25075);
    });

    test('has no floating point error on tricky decimals', () {
      expect(parseTakaToPoisha('0.1'), 10);
      expect(parseTakaToPoisha('19.99'), 1999);
      expect(parseTakaToPoisha('1.15'), 115);
    });

    test('returns null for anything else', () {
      for (final bad in [
        '',
        '  ',
        'abc',
        '1.234',
        '1.',
        '.5',
        '--5',
        '1e5',
        '1 000',
        '12345678901234',
      ]) {
        expect(parseTakaToPoisha(bad), isNull, reason: '"$bad"');
      }
    });
  });

  group('poishaToInput', () {
    test('drops the decimals when there are none', () {
      expect(poishaToInput(0), '0');
      expect(poishaToInput(150000), '1500');
    });

    test('keeps two decimals otherwise', () {
      expect(poishaToInput(150050), '1500.50');
      expect(poishaToInput(5), '0.05');
      expect(poishaToInput(-25075), '-250.75');
    });

    test('round-trips through parseTakaToPoisha', () {
      for (final value in [
        0,
        1,
        99,
        100,
        101,
        123456,
        -1,
        -99999,
        99999999999900,
      ]) {
        expect(parseTakaToPoisha(poishaToInput(value)), value);
      }
    });
  });
}
