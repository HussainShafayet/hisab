import 'package:hishab/core/utils/money.dart';

// The keypad builds an expression like `1200+350.5×2`. Operators are + - × ÷
// (a plain hyphen is the minus sign). The functions below are pure, so they
// are easy to test: [applyKey] turns a key press into the next expression and
// [evaluateAmount] turns an expression into poisha.

const _operators = '+-×÷';
final _operatorPattern = RegExp(r'[+\-×÷]');
const _maxLength = 40;
const _maxIntegerDigits = 12;

/// 999,999,999,999.99 BDT in poisha.
const _maxPoisha = 99999999999999;

bool _isOperator(String char) => char.length == 1 && _operators.contains(char);

String _lastNumber(String expression) =>
    expression.split(_operatorPattern).last;

/// The expression after pressing [key]: a digit, `.`, an operator
/// (`+ - × ÷`), `⌫` to delete the last character or `C` to clear. Presses
/// that would make the expression invalid (two dots in a number, a third
/// decimal, two operators in a row, a leading operator) change nothing, or
/// replace the previous operator.
String applyKey(String expression, String key) {
  if (key == 'C') return '';
  if (key == '⌫') {
    return expression.isEmpty
        ? expression
        : expression.substring(0, expression.length - 1);
  }
  if (_isOperator(key)) return _appendOperator(expression, key);
  if (key == '.') return _appendDot(expression);
  if (RegExp(r'^\d$').hasMatch(key)) return _appendDigit(expression, key);
  return expression;
}

String _appendDigit(String expression, String digit) {
  final number = _lastNumber(expression);
  if (number == '0') {
    // Replace a lone zero: 0 then 5 is 5, not 05.
    return expression.substring(0, expression.length - 1) + digit;
  }
  if (expression.length >= _maxLength) return expression;
  final dot = number.indexOf('.');
  if (dot >= 0) {
    return number.length - dot - 1 >= 2 ? expression : expression + digit;
  }
  return number.length >= _maxIntegerDigits ? expression : expression + digit;
}

String _appendDot(String expression) {
  if (expression.length >= _maxLength) return expression;
  final number = _lastNumber(expression);
  if (number.contains('.')) return expression;
  return number.isEmpty ? '${expression}0.' : '$expression.';
}

String _appendOperator(String expression, String operator) {
  if (expression.isEmpty) return expression;
  final last = expression[expression.length - 1];
  if (_isOperator(last) || last == '.') {
    return expression.substring(0, expression.length - 1) + operator;
  }
  return expression.length >= _maxLength ? expression : expression + operator;
}

/// The value of [expression] in poisha, rounded to the nearest poisha, or
/// null if it cannot be calculated (empty, division by zero, too large).
/// A dangling operator or dot is ignored, so `12+` is 12. The result can be
/// zero or negative, for example `5-10`: the caller decides if that is
/// acceptable.
///
/// Multiplication and division go before addition and subtraction. The
/// calculation uses exact fractions, so there is no floating point error:
/// `0.1+0.2` is exactly 0.30.
int? evaluateAmount(String expression) {
  var text = expression.trim();
  while (text.isNotEmpty &&
      (text.endsWith('.') || _isOperator(text[text.length - 1]))) {
    text = text.substring(0, text.length - 1);
  }
  if (text.isEmpty) return null;

  final numbers = <_Fraction>[];
  final operators = <String>[];
  final buffer = StringBuffer();

  bool flushNumber() {
    var token = buffer.toString();
    buffer.clear();
    if (token.endsWith('.')) token = token.substring(0, token.length - 1);
    final poisha = parseTakaToPoisha(token);
    if (poisha == null || poisha < 0) return false;
    numbers.add(_Fraction(BigInt.from(poisha), BigInt.from(poishaPerTaka)));
    return true;
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (_isOperator(char)) {
      if (!flushNumber()) return null;
      operators.add(char);
    } else {
      buffer.write(char);
    }
  }
  if (!flushNumber()) return null;

  // Multiplication and division first.
  final terms = <_Fraction>[numbers.first];
  final sumOperators = <String>[];
  for (var i = 0; i < operators.length; i++) {
    final next = numbers[i + 1];
    switch (operators[i]) {
      case '×':
        terms.last = terms.last * next;
      case '÷':
        if (next.isZero) return null;
        terms.last = terms.last / next;
      default:
        sumOperators.add(operators[i]);
        terms.add(next);
    }
  }

  var total = terms.first;
  for (var i = 0; i < sumOperators.length; i++) {
    total = sumOperators[i] == '+'
        ? total + terms[i + 1]
        : total - terms[i + 1];
  }

  final poisha = total.roundedPoisha();
  return poisha.abs() > BigInt.from(_maxPoisha) ? null : poisha.toInt();
}

/// An exact fraction of taka, so intermediate results are never rounded.
class _Fraction {
  factory _Fraction(BigInt numerator, BigInt denominator) {
    final divisor = numerator.gcd(denominator);
    var n = numerator ~/ divisor;
    var d = denominator ~/ divisor;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    return _Fraction._(n, d);
  }

  const _Fraction._(this.numerator, this.denominator);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;

  _Fraction operator +(_Fraction o) => _Fraction(
    numerator * o.denominator + o.numerator * denominator,
    denominator * o.denominator,
  );

  _Fraction operator -(_Fraction o) => _Fraction(
    numerator * o.denominator - o.numerator * denominator,
    denominator * o.denominator,
  );

  _Fraction operator *(_Fraction o) =>
      _Fraction(numerator * o.numerator, denominator * o.denominator);

  _Fraction operator /(_Fraction o) =>
      _Fraction(numerator * o.denominator, denominator * o.numerator);

  /// The value in poisha, rounded half away from zero.
  BigInt roundedPoisha() {
    final scaled = numerator * BigInt.from(poishaPerTaka);
    final magnitude =
        (scaled.abs() * BigInt.two + denominator) ~/ (denominator * BigInt.two);
    return scaled.isNegative ? -magnitude : magnitude;
  }
}
