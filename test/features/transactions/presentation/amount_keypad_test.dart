import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';

void main() {
  Future<List<String>> pumpKeypad(WidgetTester tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AmountKeypad(onKey: pressed.add)),
      ),
    );
    return pressed;
  }

  testWidgets('has digits, a dot, backspace and the four operators', (
    tester,
  ) async {
    await pumpKeypad(tester);

    for (final key in '0123456789.⌫+-×÷'.split('')) {
      expect(find.byKey(ValueKey('key-$key')), findsOneWidget, reason: key);
    }
  });

  testWidgets('reports every key it is given', (tester) async {
    final pressed = await pumpKeypad(tester);

    for (final key in '7.5⌫+-×÷0'.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$key')));
    }

    expect(pressed, '7.5⌫+-×÷0'.split(''));
  });

  testWidgets('holding backspace clears everything', (tester) async {
    final pressed = await pumpKeypad(tester);

    await tester.longPress(find.byKey(const ValueKey('key-⌫')));

    expect(pressed, ['C']);
  });

  testWidgets('shows a proper minus sign for the hyphen key', (tester) async {
    await pumpKeypad(tester);

    expect(find.text('−'), findsOneWidget);
  });
}
