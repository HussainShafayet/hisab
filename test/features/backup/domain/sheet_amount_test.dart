import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/backup/domain/sheet_amount.dart';

void main() {
  test('reads plain numbers', () {
    expect(parseSheetAmount('1200'), 120000);
    expect(parseSheetAmount('1200.5'), 120050);
    expect(parseSheetAmount('0.05'), 5);
    expect(parseSheetAmount('0'), 0);
    expect(parseSheetAmount('  350  '), 35000);
  });

  test('ignores currency marks and words', () {
    expect(parseSheetAmount('৳1,200'), 120000);
    expect(parseSheetAmount('Tk 1200'), 120000);
    expect(parseSheetAmount('tk. 1,200.50'), 120050);
    expect(parseSheetAmount('1200 BDT'), 120000);
    expect(parseSheetAmount('1200 taka'), 120000);
  });

  test('ignores grouping commas in any style', () {
    expect(parseSheetAmount('1,200'), 120000);
    expect(parseSheetAmount('1,20,000.50'), 12000050); // lakh style
    expect(parseSheetAmount('1,234,567'), 123456700);
  });

  test('a space groups digits too', () {
    expect(parseSheetAmount('1 200'), 120000);
    expect(parseSheetAmount('12 34'), 123400);
  });

  test('reads Bengali digits', () {
    expect(parseSheetAmount('১২০০'), 120000);
    expect(parseSheetAmount('৳ ১,২৫০.৫০'), 125050);
  });

  test('keeps the sign: minus, trailing minus and brackets', () {
    expect(parseSheetAmount('-250'), -25000);
    expect(parseSheetAmount('−250'), -25000); // the proper minus sign
    expect(parseSheetAmount('250-'), -25000);
    expect(parseSheetAmount('(250.75)'), -25075);
    expect(parseSheetAmount('+250'), 25000);
    expect(parseSheetAmount('-৳1,200'), -120000);
  });

  test('rounds more than two decimals to the nearest poisha', () {
    expect(parseSheetAmount('33.333333'), 3333);
    expect(parseSheetAmount('66.666'), 6667);
    expect(parseSheetAmount('0.005'), 1);
    expect(parseSheetAmount('0.004'), 0);
    expect(parseSheetAmount('1.995'), 200); // carries into the taka
  });

  test('reads a decimal point without a whole part', () {
    expect(parseSheetAmount('.5'), 50);
    expect(parseSheetAmount('250.'), 25000);
  });

  test('is null for anything that is not an amount', () {
    for (final bad in [
      '',
      '  ',
      'abc',
      '12abc',
      '1.2.3',
      '--5',
      '.',
      '-',
      '1e5',
    ]) {
      expect(parseSheetAmount(bad), isNull, reason: '"$bad"');
    }
  });

  test('is null beyond twelve digits of taka', () {
    expect(parseSheetAmount('999999999999'), 99999999999900);
    expect(parseSheetAmount('1000000000000'), isNull);
  });
}
