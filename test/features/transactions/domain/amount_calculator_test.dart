import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/amount_calculator.dart';

/// Presses [keys] one after another, like tapping the keypad.
String type(String keys, {String from = ''}) {
  var expression = from;
  for (final key in keys.split('')) {
    expression = applyKey(expression, key);
  }
  return expression;
}

void main() {
  group('applyKey', () {
    test('builds numbers and expressions', () {
      expect(type('1200'), '1200');
      expect(type('12.5'), '12.5');
      expect(type('1200+350×2'), '1200+350×2');
    });

    test('a leading zero is replaced by the next digit', () {
      expect(type('05'), '5');
      expect(type('007'), '7');
      expect(type('0'), '0');
      expect(type('10+05'), '10+5');
    });

    test('zero followed by a dot stays a decimal', () {
      expect(type('0.5'), '0.5');
      expect(type('0.05'), '0.05');
    });

    test('a dot at the start or after an operator gets a zero in front', () {
      expect(type('.5'), '0.5');
      expect(type('3+.5'), '3+0.5');
    });

    test('only one dot per number', () {
      expect(type('1.2.3'), '1.23');
      expect(type('1.5+2.5.5'), '1.5+2.55');
    });

    test('at most two decimals per number', () {
      expect(type('1.2345'), '1.23');
      expect(type('1.234+5.678'), '1.23+5.67');
    });

    test('at most twelve integer digits per number', () {
      expect(type('1234567890123'), '123456789012');
      expect(type('1+1234567890123'), '1+123456789012');
    });

    test('limits the whole expression length', () {
      final long = type('1+' * 30);
      expect(long.length, lessThanOrEqualTo(40));
    });

    test('ignores an operator at the start', () {
      expect(type('+'), '');
      expect(type('-'), '');
      expect(type('×5'), '5');
    });

    test('a second operator replaces the first', () {
      expect(type('5+-'), '5-');
      expect(type('5×÷3'), '5÷3');
    });

    test('an operator after a dot drops the dot', () {
      expect(type('5.+'), '5+');
    });

    test('backspace removes the last character', () {
      expect(applyKey('12+3', '⌫'), '12+');
      expect(applyKey('7', '⌫'), '');
      expect(applyKey('', '⌫'), '');
    });

    test('C clears everything', () {
      expect(applyKey('12+3', 'C'), '');
    });

    test('ignores unknown keys', () {
      expect(applyKey('12', 'x'), '12');
      expect(applyKey('12', '10'), '12');
    });
  });

  group('evaluateAmount', () {
    test('returns a plain number in poisha', () {
      expect(evaluateAmount('1500'), 150000);
      expect(evaluateAmount('12.5'), 1250);
      expect(evaluateAmount('0.05'), 5);
    });

    test('is null for nothing to calculate', () {
      expect(evaluateAmount(''), isNull);
      expect(evaluateAmount('   '), isNull);
      expect(evaluateAmount('+'), isNull);
    });

    test('adds and subtracts', () {
      expect(evaluateAmount('1200+350'), 155000);
      expect(evaluateAmount('1200-350.5'), 84950);
      expect(evaluateAmount('1+2+3-1'), 500);
    });

    test('multiplies and divides', () {
      expect(evaluateAmount('250×3'), 75000);
      expect(evaluateAmount('1000÷4'), 25000);
      expect(evaluateAmount('10×0.5'), 500);
    });

    test('multiplication and division go before addition', () {
      expect(evaluateAmount('2+3×4'), 1400);
      expect(evaluateAmount('10-6÷2'), 700);
      expect(evaluateAmount('2×3+4×5'), 2600);
    });

    test('has no floating point error', () {
      expect(evaluateAmount('0.1+0.2'), 30);
      expect(evaluateAmount('19.99×3'), 5997);
      expect(evaluateAmount('1.15×100'), 11500);
    });

    test('rounds to the nearest poisha, half away from zero', () {
      expect(evaluateAmount('100÷3'), 3333); // 33.333...
      expect(evaluateAmount('200÷3'), 6667); // 66.666...
      expect(evaluateAmount('0.01÷2'), 1); // 0.005 rounds up
      expect(evaluateAmount('0.03÷2'), 2); // 0.015 rounds up
      expect(evaluateAmount('0-0.03÷2'), -2); // -0.015 rounds away from zero
      expect(evaluateAmount('0.01-0.02÷2×3'), -2); // -0.02 exactly
    });

    test('divides exactly before rounding', () {
      expect(evaluateAmount('100÷3×3'), 10000);
    });

    test('is null when dividing by zero', () {
      expect(evaluateAmount('5÷0'), isNull);
      expect(evaluateAmount('5÷0.00'), isNull);
    });

    test('can be zero or negative; the caller decides', () {
      expect(evaluateAmount('5-5'), 0);
      expect(evaluateAmount('5-10'), -500);
    });

    test('ignores a dangling operator or dot', () {
      expect(evaluateAmount('12+'), 1200);
      expect(evaluateAmount('12.'), 1200);
      expect(evaluateAmount('12×3+'), 3600);
    });

    test('is null for malformed input', () {
      expect(evaluateAmount('1++2'), isNull);
      expect(evaluateAmount('1.234'), isNull);
      expect(evaluateAmount('abc'), isNull);
    });

    test('is null above the largest amount', () {
      expect(evaluateAmount('999999999999×2'), isNull);
      expect(evaluateAmount('999999999999.99'), 99999999999999);
    });

    test('evaluates what the keypad builds', () {
      expect(evaluateAmount(type('1200+350.5×2')), 190100);
    });
  });
}
