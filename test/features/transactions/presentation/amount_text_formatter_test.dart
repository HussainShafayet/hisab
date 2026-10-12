import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_text_formatter.dart';

TextEditingValue format(String text) => AmountTextFormatter().formatEditUpdate(
  TextEditingValue.empty,
  TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  ),
);

void main() {
  test('leaves a valid number, and its cursor, alone', () {
    final value = TextEditingValue(
      text: '12.5',
      selection: const TextSelection.collapsed(offset: 1),
    );

    final result = AmountTextFormatter().formatEditUpdate(
      TextEditingValue.empty,
      value,
    );

    expect(result, same(value));
  });

  test('cleans what was typed or pasted and puts the cursor at the end', () {
    final result = format('1,5');

    expect(result.text, '15');
    expect(result.selection, const TextSelection.collapsed(offset: 2));
  });

  test('turns Bengali digits into ordinary ones', () {
    expect(format('১২৩').text, '123');
  });

  test('cuts a third decimal', () {
    expect(format('1.234').text, '1.23');
  });

  test('empties the field of letters', () {
    expect(format('abc').text, '');
  });
}
