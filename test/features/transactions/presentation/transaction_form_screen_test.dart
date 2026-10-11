import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Future<void> tapKeys(WidgetTester tester, String keys) async {
  for (final key in keys.split('')) {
    await tester.tap(find.byKey(ValueKey('key-$key')));
  }
  await tester.pump();
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

String amountShown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('amount-display'))).data!;

bool isSelected(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;

Future<List<TransactionRow>> savedRows(AppDatabase db) =>
    db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

void main() {
  group('saving an expense', () {
    testWithDatabase('takes an amount, a category and Save', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapKeys(tester, '250');
      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      await tapText(tester, 'Save');

      // Back on the screen that opened the form.
      expect(appBarTitle('Home'), findsOneWidget);
      final row = (await savedRows(db)).single;
      expect(row.type, TransactionType.expense);
      expect(row.amount, 25000);
      expect(row.accountId, b.cash);
      expect(row.categoryId, b.food);
      expect(row.date, testNow);
      expect(row.toAccountId, isNull);
    });

    testWithDatabase('adds up a calculation', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapKeys(tester, '1200+350.5×2');

      expect(amountShown(tester), '৳ 1200+350.5×2');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('amount-result'))).data,
        '= ৳1,901.00',
      );

      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      await tapText(tester, 'Save');

      expect((await savedRows(db)).single.amount, 190100);
    });

    testWithDatabase('backspace deletes a key and holding it clears all', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      expect(amountShown(tester), '৳ 0');

      await tapKeys(tester, '125');
      await tapKeys(tester, '⌫');
      expect(amountShown(tester), '৳ 12');

      await tester.longPress(find.byKey(const ValueKey('key-⌫')));
      await tester.pump();
      expect(amountShown(tester), '৳ 0');
    });

    testWithDatabase('does not accept more than two decimals', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapKeys(tester, '1.2345');

      expect(amountShown(tester), '৳ 1.23');
    });

    testWithDatabase('asks for an amount', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      await tapText(tester, 'Save');

      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(appBarTitle('Add transaction'), findsOneWidget);
      expect(await savedRows(db), isEmpty);
    });

    testWithDatabase('asks for a category', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapKeys(tester, '50');
      await tapText(tester, 'Save');

      expect(find.text('Choose a category.'), findsOneWidget);
      expect(await savedRows(db), isEmpty);
    });

    testWithDatabase('treats zero and a negative result as no amount', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      await tester.tap(find.byKey(ValueKey('category-${b.food}')));

      await tapKeys(tester, '5-10');
      await tapText(tester, 'Save');

      expect(find.text('Enter an amount.'), findsOneWidget);
    });

    testWithDatabase('keeps the note, trimmed', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapKeys(tester, '80');
      await tester.tap(find.byKey(ValueKey('category-${b.transport}')));
      await tester.enterText(
        find.widgetWithText(TextField, 'Note'),
        '  Rickshaw  ',
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');

      expect((await savedRows(db)).single.note, 'Rickshaw');
    });
  });

  group('income', () {
    testWithDatabase('shows income categories and saves an income', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      expect(find.byKey(ValueKey('category-${b.salary}')), findsNothing);

      await tapText(tester, 'Income');
      expect(find.byKey(ValueKey('category-${b.food}')), findsNothing);
      await tapKeys(tester, '50000');
      await tester.tap(find.byKey(ValueKey('category-${b.salary}')));
      await tester.pump();
      await tapText(tester, 'Save');

      final row = (await savedRows(db)).single;
      expect(row.type, TransactionType.income);
      expect(row.categoryId, b.salary);
      expect(row.amount, 5000000);
    });

    testWithDatabase('changing the type clears the chosen category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      expect(isSelected(tester, 'category-${b.food}'), isTrue);

      await tapText(tester, 'Income');
      await tapText(tester, 'Expense');

      expect(isSelected(tester, 'category-${b.food}'), isFalse);
    });
  });

  group('choices', () {
    testWithDatabase('start with the account used last', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 100,
        accountId: b.bkash,
        categoryId: b.food,
        date: DateTime(2026, 10, 5),
      );
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      expect(isSelected(tester, 'account-${b.bkash}'), isTrue);
      expect(isSelected(tester, 'account-${b.cash}'), isFalse);
    });

    testWithDatabase('save to the account that was picked', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapKeys(tester, '70');
      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.tap(find.byKey(ValueKey('account-${b.bkash}')));
      await tester.pump();
      await tapText(tester, 'Save');

      expect((await savedRows(db)).single.accountId, b.bkash);
    });

    testWithDatabase('list the most used categories first', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      for (var i = 0; i < 3; i++) {
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 100,
          accountId: b.cash,
          categoryId: b.transport,
          date: DateTime(2026, 10, 1 + i),
        );
      }
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      final transportX = tester.getTopLeft(
        find.byKey(ValueKey('category-${b.transport}')),
      );
      final foodX = tester.getTopLeft(
        find.byKey(ValueKey('category-${b.food}')),
      );
      // Same row, Transport to the left of Food (Food was created first).
      expect(transportX.dy, foodX.dy);
      expect(transportX.dx, lessThan(foodX.dx));
    });

    testWithDatabase('offer Today and Yesterday', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      expect(isSelected(tester, 'date-today'), isTrue);

      await tester.tap(find.byKey(const ValueKey('date-yesterday')));
      await tester.pump();
      expect(isSelected(tester, 'date-yesterday'), isTrue);
      expect(isSelected(tester, 'date-today'), isFalse);

      await tapKeys(tester, '30');
      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      await tapText(tester, 'Save');

      // Yesterday, at the time of day it is now.
      expect((await savedRows(db)).single.date, DateTime(2026, 10, 10, 14, 30));
    });

    testWithDatabase('pick any other date', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tester.tap(find.byKey(const ValueKey('date-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(isSelected(tester, 'date-other'), isTrue);
      expect(find.text('3 Oct'), findsOneWidget);

      await tapKeys(tester, '10');
      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      await tapText(tester, 'Save');

      expect((await savedRows(db)).single.date, DateTime(2026, 10, 3, 14, 30));
    });

    testWithDatabase('hide the keypad while the note is being typed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      expect(find.byType(AmountKeypad), findsOneWidget);

      await tester.tap(find.widgetWithText(TextField, 'Note'));
      await tester.pumpAndSettle();

      expect(find.byType(AmountKeypad), findsNothing);
    });
  });

  group('save and add another', () {
    testWithDatabase('saves, clears the amount and category, keeps the rest', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tester.tap(find.byKey(const ValueKey('date-yesterday')));
      await tester.tap(find.byKey(ValueKey('account-${b.bkash}')));
      await tapKeys(tester, '250');
      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      await tapText(tester, 'Save & add another');

      // Still on the form, ready for the next one.
      expect(appBarTitle('Add transaction'), findsOneWidget);
      expect(find.text('Saved ৳250.00'), findsOneWidget);
      expect(amountShown(tester), '৳ 0');
      expect(isSelected(tester, 'category-${b.food}'), isFalse);
      expect(isSelected(tester, 'account-${b.bkash}'), isTrue);
      expect(isSelected(tester, 'date-yesterday'), isTrue);

      await tapKeys(tester, '40');
      await tester.tap(find.byKey(ValueKey('category-${b.transport}')));
      await tester.pump();
      await tapText(tester, 'Save');

      final rows = await savedRows(db);
      expect(rows.map((r) => r.amount), [4000, 25000]);
      expect(rows.every((r) => r.accountId == b.bkash), isTrue);
      expect(appBarTitle('Home'), findsOneWidget);
    });

    testWithDatabase('does not clear anything when saving fails', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapKeys(tester, '250');
      await tapText(tester, 'Save & add another');

      expect(find.text('Choose a category.'), findsOneWidget);
      expect(amountShown(tester), '৳ 250');
    });
  });

  group('transfer', () {
    testWithDatabase('moves money and records the fee as an expense', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapText(tester, 'Transfer');
      expect(find.byKey(ValueKey('category-${b.food}')), findsNothing);
      expect(isSelected(tester, 'from-${b.cash}'), isTrue);
      await tester.tap(find.byKey(ValueKey('to-${b.bkash}')));
      await tester.pump();
      await tapKeys(tester, '1000');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fee (optional)'),
        '15',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');

      final rows = await savedRows(db);
      final transfer = rows.singleWhere(
        (r) => r.type == TransactionType.transfer,
      );
      final fee = rows.singleWhere((r) => r.type == TransactionType.expense);
      expect(rows, hasLength(2));
      expect(transfer.amount, 100000);
      expect(transfer.accountId, b.cash);
      expect(transfer.toAccountId, b.bkash);
      expect(transfer.categoryId, isNull);
      expect(fee.amount, 1500);
      expect(fee.accountId, b.cash);
      final category = (await db.categoriesDao.getById(fee.categoryId!))!;
      expect(category.name, transferFeeCategoryName);
    });

    testWithDatabase('cannot pick the same account on both sides', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      await tapText(tester, 'Transfer');

      // Cash is "From", so it is not available as "To".
      final cashAsTo = tester.widget<ChoiceChip>(
        find.byKey(ValueKey('to-${b.cash}')),
      );
      expect(cashAsTo.onSelected, isNull);
    });

    testWithDatabase('asks for the account the money goes to', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      await tapText(tester, 'Transfer');

      await tapKeys(tester, '500');
      await tapText(tester, 'Save');

      expect(
        find.text('Choose the account the money goes to.'),
        findsOneWidget,
      );
      expect(await savedRows(db), isEmpty);
    });

    testWithDatabase('rejects a fee that is not an amount', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);
      await tapText(tester, 'Transfer');
      await tester.tap(find.byKey(ValueKey('to-${b.bkash}')));
      await tapKeys(tester, '500');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fee (optional)'),
        '1.234',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');

      expect(find.textContaining('valid fee'), findsOneWidget);
      expect(await savedRows(db), isEmpty);
    });

    testWithDatabase('needs two accounts', (tester, db) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      await tapText(tester, 'Transfer');

      expect(find.text('You need two accounts'), findsOneWidget);
    });
  });

  group('empty states', () {
    testWithDatabase('ask for an account first', (tester, db) async {
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      expect(find.text('Add an account first'), findsOneWidget);

      await tapText(tester, 'Add account');
      expect(appBarTitle('New account'), findsOneWidget);
    });

    testWithDatabase('offer to add a category when there is none', (
      tester,
      db,
    ) async {
      await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openForm(tester);

      expect(find.text('Add an expense category'), findsOneWidget);

      await tapText(tester, 'Income');
      expect(find.text('Add an income category'), findsOneWidget);
    });
  });
}
