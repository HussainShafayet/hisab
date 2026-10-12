import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Things a person does on the add / edit transaction form, shared by the
/// tests that open it.

final amountField = find.byKey(const ValueKey('amount-field'));

/// Taps the global add button.
Future<void> openAddForm(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

/// Types [text] into the amount field, as the keyboard would.
Future<void> typeAmount(WidgetTester tester, String text) async {
  await tester.enterText(amountField, text);
  await tester.pump();
}

/// What the amount field holds.
String amountText(WidgetTester tester) =>
    tester.widget<TextField>(amountField).controller!.text;

/// Switches the amount to the calculator keypad.
Future<void> turnCalculatorOn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('calculator-toggle')));
  await tester.pumpAndSettle();
}

/// Presses keypad keys, for example `'1200+350'`.
Future<void> tapCalcKeys(WidgetTester tester, String keys) async {
  for (final key in keys.split('')) {
    await tester.tap(find.byKey(ValueKey('key-$key')));
  }
  await tester.pump();
}

/// Opens the category picker and taps the category with [id]. It has to be on
/// screen: a top-level one, or one inside a category that is open.
Future<void> chooseCategory(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(const ValueKey('category-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('category-option-$id')));
  await tester.pumpAndSettle();
}

/// What the category field of the form says.
String categoryShown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('category-value'))).data!;

/// Opens the account sheet behind the field with key [field]
/// (`account-field`, `from-field` or `to-field`) and taps the account [id].
Future<void> chooseAccount(
  WidgetTester tester, {
  required String field,
  required int id,
}) async {
  await tester.tap(find.byKey(ValueKey(field)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('account-option-$id')));
  await tester.pumpAndSettle();
}

/// The text of the balance line "After this" for account [id].
String balanceAfter(WidgetTester tester, int id) =>
    tester.widget<Text>(find.byKey(ValueKey('balance-after-$id'))).data!;

/// The text of the current balance for account [id] on its card.
String balanceNow(WidgetTester tester, int id) =>
    tester.widget<Text>(find.byKey(ValueKey('balance-$id'))).data!;
