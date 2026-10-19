import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';

/// Things a person does on the add / edit transaction form, shared by the
/// tests that open it.

final amountField = find.byKey(const ValueKey('amount-field'));

/// Taps the global add button.
Future<void> openAddForm(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

/// Types [text] into the amount field. A new transaction starts with the
/// calculator keypad, so this clears the amount and presses the keys (opening
/// the keypad first if it was put away); with the keyboard it enters the text
/// as the keyboard would.
Future<void> typeAmount(WidgetTester tester, String text) async {
  if (tester.widget<TextField>(amountField).readOnly) {
    if (find.byType(AmountKeypad).evaluate().isEmpty) {
      await tester.tap(amountField);
      await tester.pumpAndSettle();
    }
    await tester.longPress(find.byKey(const ValueKey('key-⌫')));
    await tester.pump();
    await tapCalcKeys(tester, text);
    return;
  }
  await tester.enterText(amountField, text);
  await tester.pump();
}

/// What the amount field holds.
String amountText(WidgetTester tester) =>
    tester.widget<TextField>(amountField).controller!.text;

/// Makes sure the calculator keypad is on screen. A new transaction starts
/// with it; if it was put away (after a category was chosen) it is opened
/// again; from the keyboard the calculator button switches to it.
Future<void> turnCalculatorOn(WidgetTester tester) async {
  final calculator = tester.widget<TextField>(amountField).readOnly;
  final edit = find.byKey(const ValueKey('amount-edit'));
  if (calculator) {
    // Already the entry mode: only bring the keypad back if it was put away.
    if (edit.evaluate().isEmpty) return;
    await tester.tap(edit);
  } else {
    await tester.tap(find.byKey(const ValueKey('calculator-toggle')));
  }
  await tester.pumpAndSettle();
}

/// Switches the amount from the calculator to the plain keyboard.
Future<void> turnKeyboardOn(WidgetTester tester) async {
  if (!tester.widget<TextField>(amountField).readOnly) return;
  await tester.tap(find.byKey(const ValueKey('calculator-toggle')));
  await tester.pumpAndSettle();
}

/// Opens "More details" (the trip or event and the feeling) on a new form.
Future<void> openMoreDetails(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('more-details'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
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
  final field = find.byKey(const ValueKey('category-field'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
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
  await tester.ensureVisible(find.byKey(ValueKey(field)));
  await tester.pumpAndSettle();
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
