import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<List<TransactionRow>> savedRows(AppDatabase db) =>
    db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// A card of the form (`account-field`, `from-field`, `to-field`) shows this
/// account.
Finder accountOnCard(String field, String name) =>
    find.descendant(of: find.byKey(ValueKey(field)), matching: find.text(name));

/// Cash holds 5,000 taka, so balances have something to show.
Future<void> giveCash5000(AppDatabase db, Basics b) => addTransaction(
  db,
  type: TransactionType.income,
  amount: 500000,
  accountId: b.cash,
  categoryId: b.salary,
  date: DateTime(2026, 10, 1),
);

void main() {
  group('the amount', () {
    testWithDatabase('is typed on the keyboard, with no keypad in the way', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(amountField, findsOneWidget);
      expect(find.byType(AmountKeypad), findsNothing);
      // A new transaction starts with the cursor in the amount.
      expect(
        FocusManager.instance.primaryFocus,
        tester.widget<TextField>(amountField).focusNode,
      );
    });

    testWithDatabase('keeps only a valid number', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '12.345');
      expect(amountText(tester), '12.34');

      await typeAmount(tester, '১২৩');
      expect(amountText(tester), '123');

      await typeAmount(tester, '1,500.50');
      expect(amountText(tester), '1500.50');

      await typeAmount(tester, 'abc');
      expect(amountText(tester), '');
    });

    testWithDatabase('is saved from what was typed', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '250');
      await chooseCategory(tester, b.food);
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

    testWithDatabase('moves on to the category when the keyboard says done', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '40');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryPickerSheet), findsOneWidget);
    });
  });

  group('the calculator', () {
    testWithDatabase('is one tap away and adds up a calculation', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await turnCalculatorOn(tester);
      expect(find.byType(AmountKeypad), findsOneWidget);
      await tapCalcKeys(tester, '1200+350.5×2');

      expect(amountText(tester), '1200+350.5×2');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('amount-result'))).data,
        '= ৳1,901.00',
      );

      await chooseCategory(tester, b.food);
      await tapText(tester, 'Save');

      expect((await savedRows(db)).single.amount, 190100);
    });

    testWithDatabase('turns a sum into its result when you go back', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await turnCalculatorOn(tester);
      await tapCalcKeys(tester, '10+5');
      await tester.tap(find.byKey(const ValueKey('calculator-toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(AmountKeypad), findsNothing);
      expect(amountText(tester), '15');
      expect(find.byKey(const ValueKey('amount-result')), findsNothing);
    });

    testWithDatabase('keeps a plain number when you go back', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '75.5');
      await turnCalculatorOn(tester);
      expect(amountText(tester), '75.5');
      await tapCalcKeys(tester, '+4');
      expect(amountText(tester), '75.5+4');
    });

    testWithDatabase('stays open when the sum cannot be worked out', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await turnCalculatorOn(tester);
      await tapCalcKeys(tester, '5÷0');
      await tester.tap(find.byKey(const ValueKey('calculator-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Check the calculation first.'), findsOneWidget);
      expect(find.byType(AmountKeypad), findsOneWidget);
    });

    testWithDatabase('backspace deletes a key and holding it clears all', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await turnCalculatorOn(tester);
      expect(amountText(tester), '');

      await tapCalcKeys(tester, '125');
      await tapCalcKeys(tester, '⌫');
      expect(amountText(tester), '12');

      await tester.longPress(find.byKey(const ValueKey('key-⌫')));
      await tester.pump();
      expect(amountText(tester), '');
    });

    testWithDatabase('does not accept more than two decimals', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await turnCalculatorOn(tester);

      await tapCalcKeys(tester, '1.2345');

      expect(amountText(tester), '1.23');
    });

    testWithDatabase('hides the keypad while the note is being typed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await turnCalculatorOn(tester);
      expect(find.byType(AmountKeypad), findsOneWidget);

      await tester.tap(find.widgetWithText(TextField, 'Note'));
      await tester.pumpAndSettle();

      expect(find.byType(AmountKeypad), findsNothing);
    });
  });

  group('saving an expense', () {
    testWithDatabase('asks for an amount', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await chooseCategory(tester, b.food);
      await tapText(tester, 'Save');

      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(appBarTitle('Add transaction'), findsOneWidget);
      expect(await savedRows(db), isEmpty);
    });

    testWithDatabase('asks for a category', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '50');
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
      await openAddForm(tester);
      await chooseCategory(tester, b.food);

      await turnCalculatorOn(tester);
      await tapCalcKeys(tester, '5-10');
      await tapText(tester, 'Save');

      expect(find.text('Enter an amount.'), findsOneWidget);
    });

    testWithDatabase('keeps the note, trimmed', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '80');
      await chooseCategory(tester, b.transport);
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
      await openAddForm(tester);

      await tapText(tester, 'Income');
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('category-option-${b.salary}')), findsOne);
      expect(find.byKey(ValueKey('category-option-${b.food}')), findsNothing);
      await tester.tap(find.byKey(ValueKey('category-option-${b.salary}')));
      await tester.pumpAndSettle();
      await typeAmount(tester, '50000');
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
      await openAddForm(tester);

      await chooseCategory(tester, b.food);
      expect(categoryShown(tester), 'Food');

      await tapText(tester, 'Income');
      await tapText(tester, 'Expense');

      expect(categoryShown(tester), 'Choose a category');
    });
  });

  group('choosing a category', () {
    testWithDatabase('shows the whole path of a deep category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final groceries = await insertTestCategory(
        db,
        name: 'Groceries',
        parentId: b.food,
      );
      final rice = await insertTestCategory(
        db,
        name: 'Rice',
        parentId: groceries,
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();
      // Closed to start with: only the top level shows.
      expect(find.byKey(ValueKey('category-option-$groceries')), findsNothing);
      await tester.tap(find.byKey(ValueKey('category-expand-${b.food}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('category-option-$groceries')), findsOne);
      expect(find.byKey(ValueKey('category-option-$rice')), findsNothing);
      await tester.tap(find.byKey(ValueKey('category-expand-$groceries')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('category-option-$rice')));
      await tester.pumpAndSettle();

      expect(categoryShown(tester), 'Food › Groceries › Rice');
      await typeAmount(tester, '60');
      await tapText(tester, 'Save');
      expect((await savedRows(db)).single.categoryId, rice);
    });

    testWithDatabase('opens and closes a category with its arrow', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final groceries = await insertTestCategory(
        db,
        name: 'Groceries',
        parentId: b.food,
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('category-expand-${b.food}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('category-option-$groceries')), findsOne);

      await tester.tap(find.byKey(ValueKey('category-expand-${b.food}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('category-option-$groceries')), findsNothing);
    });

    testWithDatabase('a category that has others inside can be chosen too', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await insertTestCategory(db, name: 'Groceries', parentId: b.food);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await chooseCategory(tester, b.food);

      expect(categoryShown(tester), 'Food');
    });

    testWithDatabase('search finds a category at any depth', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final groceries = await insertTestCategory(
        db,
        name: 'Groceries',
        parentId: b.food,
      );
      final rice = await insertTestCategory(
        db,
        name: 'Rice',
        parentId: groceries,
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('category-search')),
        'rice',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('category-option-$rice')), findsOne);
      expect(
        find.byKey(ValueKey('category-option-${b.transport}')),
        findsNothing,
      );
      // The path it sits in is shown under its name.
      expect(find.text('Food › Groceries'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('category-option-$rice')));
      await tester.pumpAndSettle();
      expect(categoryShown(tester), 'Food › Groceries › Rice');
    });

    testWithDatabase('search also matches the name of a parent', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final groceries = await insertTestCategory(
        db,
        name: 'Groceries',
        parentId: b.food,
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('category-search')),
        'FOOD',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('category-option-${b.food}')), findsOne);
      expect(find.byKey(ValueKey('category-option-$groceries')), findsOne);
    });

    testWithDatabase('search with no match offers to add a category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('category-search')),
        'zzz',
      );
      await tester.pumpAndSettle();

      expect(find.text('No category matches "zzz".'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-empty-add')), findsOneWidget);
    });

    testWithDatabase('shows the most used categories first, as quick picks', (
      tester,
      db,
    ) async {
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
      await openAddForm(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      expect(find.text('Frequently used'), findsOneWidget);
      expect(find.byKey(ValueKey('frequent-${b.transport}')), findsOneWidget);
      expect(find.byKey(ValueKey('frequent-${b.food}')), findsNothing);

      await tester.tap(find.byKey(ValueKey('frequent-${b.transport}')));
      await tester.pumpAndSettle();
      expect(categoryShown(tester), 'Transport');
    });

    testWithDatabase('has no quick picks before anything was used', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      expect(find.text('Frequently used'), findsNothing);
    });

    testWithDatabase('marks the category chosen before', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await chooseCategory(tester, b.food);

      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(ValueKey('category-option-${b.food}')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase(
      'a new category can be made from the picker and is chosen',
      (tester, db) async {
        useTallScreen(tester);
        await seedBasics(db);
        await pumpAppWithDatabase(tester, db);
        await openAddForm(tester);
        await typeAmount(tester, '90');
        await tester.tap(find.byKey(const ValueKey('category-field')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('category-add')));
        await tester.pumpAndSettle();
        expect(appBarTitle('New category'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'),
          'Pets',
        );
        await tapText(tester, 'Add category');

        // Back on the form with what was typed still there, Pets chosen.
        expect(appBarTitle('Add transaction'), findsOneWidget);
        expect(amountText(tester), '90');
        expect(categoryShown(tester), 'Pets');
      },
    );
  });

  group('choosing an account', () {
    testWithDatabase('starts with the account used last', (tester, db) async {
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
      await openAddForm(tester);

      expect(accountOnCard('account-field', 'bKash'), findsOneWidget);
      expect(accountOnCard('account-field', 'Cash'), findsNothing);
    });

    testWithDatabase('saves to the account that was picked', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '70');
      await chooseCategory(tester, b.food);
      await chooseAccount(tester, field: 'account-field', id: b.bkash);
      expect(accountOnCard('account-field', 'bKash'), findsOneWidget);
      await tapText(tester, 'Save');

      expect((await savedRows(db)).single.accountId, b.bkash);
    });

    testWithDatabase('lists every account with its balance in the sheet', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('account-field')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('account-option-${b.cash}')), findsOne);
      expect(find.byKey(ValueKey('account-option-${b.bkash}')), findsOne);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('account-option-${b.cash}')),
          matching: find.text('৳5,000.00'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('does not offer an archived account', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await db.accountsDao.setArchived(b.bkash, archived: true);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('account-field')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('account-option-${b.bkash}')), findsNothing);
      expect(find.byKey(ValueKey('account-option-${b.cash}')), findsOne);
    });
  });

  group('the balance', () {
    testWithDatabase('shows what the account holds now', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(balanceNow(tester, b.cash), '৳5,000.00');
      // Nothing is typed, so there is nothing to compare with yet.
      expect(find.byKey(ValueKey('balance-after-${b.cash}')), findsNothing);
    });

    testWithDatabase('shows what is left after an expense', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '1200');

      expect(balanceAfter(tester, b.cash), '৳3,800.00');
    });

    testWithDatabase('follows the calculator', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await turnCalculatorOn(tester);
      await tapCalcKeys(tester, '1000+200');

      expect(balanceAfter(tester, b.cash), '৳3,800.00');
    });

    testWithDatabase('shows what the account will hold after an income', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tapText(tester, 'Income');

      await typeAmount(tester, '1200');

      expect(balanceAfter(tester, b.cash), '৳6,200.00');
    });

    testWithDatabase('changes with the account that is chosen', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await typeAmount(tester, '300');

      await chooseAccount(tester, field: 'account-field', id: b.bkash);

      expect(balanceNow(tester, b.bkash), '৳0.00');
      expect(balanceAfter(tester, b.bkash), '-৳300.00');
    });

    testWithDatabase('warns when the balance would go below zero', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '9000');

      expect(balanceAfter(tester, b.cash), '-৳4,000.00');
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWithDatabase('does not warn when there is enough', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '100');

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('choices', () {
    testWithDatabase('offer Today and Yesterday', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      bool isSelected(String key) =>
          tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;
      expect(isSelected('date-today'), isTrue);

      await tester.tap(find.byKey(const ValueKey('date-yesterday')));
      await tester.pump();
      expect(isSelected('date-yesterday'), isTrue);
      expect(isSelected('date-today'), isFalse);

      await typeAmount(tester, '30');
      await chooseCategory(tester, b.food);
      await tapText(tester, 'Save');

      // Yesterday, at the time of day it is now.
      expect((await savedRows(db)).single.date, DateTime(2026, 10, 10, 14, 30));
    });

    testWithDatabase('pick any other date', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('date-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('date-other')))
            .selected,
        isTrue,
      );
      expect(find.text('3 Oct'), findsOneWidget);

      await typeAmount(tester, '10');
      await chooseCategory(tester, b.food);
      await tapText(tester, 'Save');

      expect((await savedRows(db)).single.date, DateTime(2026, 10, 3, 14, 30));
    });
  });

  group('Save & new', () {
    testWithDatabase('saves, clears the amount and category, keeps the rest', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('date-yesterday')));
      await chooseAccount(tester, field: 'account-field', id: b.bkash);
      await typeAmount(tester, '250');
      await chooseCategory(tester, b.food);
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Lunch');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-and-new')));
      await tester.pumpAndSettle();

      // Still on the form, ready for the next one.
      expect(appBarTitle('Add transaction'), findsOneWidget);
      expect(find.text('Saved ৳250.00. Add the next one.'), findsOneWidget);
      expect(amountText(tester), '');
      expect(categoryShown(tester), 'Choose a category');
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Note'))
            .controller!
            .text,
        '',
      );
      expect(accountOnCard('account-field', 'bKash'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('date-yesterday')))
            .selected,
        isTrue,
      );

      await typeAmount(tester, '40');
      await chooseCategory(tester, b.transport);
      await tapText(tester, 'Save');

      final rows = await savedRows(db);
      expect(rows.map((r) => r.amount), [4000, 25000]);
      expect(rows.every((r) => r.accountId == b.bkash), isTrue);
      expect(appBarTitle('Home'), findsOneWidget);
    });

    testWithDatabase('puts the cursor back in the amount', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await typeAmount(tester, '25');
      await chooseCategory(tester, b.food);

      await tester.tap(find.byKey(const ValueKey('save-and-new')));
      await tester.pumpAndSettle();

      expect(
        FocusManager.instance.primaryFocus,
        tester.widget<TextField>(amountField).focusNode,
      );
    });

    testWithDatabase('updates the balance for the next one', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await typeAmount(tester, '1000');
      await chooseCategory(tester, b.food);

      await tester.tap(find.byKey(const ValueKey('save-and-new')));
      await tester.pumpAndSettle();

      expect(balanceNow(tester, b.cash), '৳4,000.00');
    });

    testWithDatabase('does not clear anything when saving fails', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '250');
      await tester.tap(find.byKey(const ValueKey('save-and-new')));
      await tester.pumpAndSettle();

      expect(find.text('Choose a category.'), findsOneWidget);
      expect(amountText(tester), '250');
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
      await openAddForm(tester);

      await tapText(tester, 'Transfer');
      expect(find.byKey(const ValueKey('category-field')), findsNothing);
      expect(accountOnCard('from-field', 'Cash'), findsOneWidget);
      await chooseAccount(tester, field: 'to-field', id: b.bkash);
      await typeAmount(tester, '1000');
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

    testWithDatabase('shows both balances after the transfer, fee included', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await giveCash5000(db, b);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tapText(tester, 'Transfer');
      await chooseAccount(tester, field: 'to-field', id: b.bkash);

      await typeAmount(tester, '1000');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fee (optional)'),
        '15',
      );
      await tester.pump();

      expect(balanceAfter(tester, b.cash), '৳3,985.00');
      expect(balanceAfter(tester, b.bkash), '৳1,000.00');
    });

    testWithDatabase('cannot pick the same account on both sides', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tapText(tester, 'Transfer');

      // Cash is "From", so it cannot be chosen as "To".
      await tester.tap(find.byKey(const ValueKey('to-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('account-option-${b.cash}')));
      await tester.pumpAndSettle();

      // The sheet is still open and nothing was chosen.
      expect(find.byKey(ValueKey('account-option-${b.bkash}')), findsOne);
    });

    testWithDatabase('swaps From and To', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tapText(tester, 'Transfer');
      await chooseAccount(tester, field: 'to-field', id: b.bkash);

      await tester.tap(find.byKey(const ValueKey('swap-accounts')));
      await tester.pump();

      expect(accountOnCard('from-field', 'bKash'), findsOneWidget);
      expect(accountOnCard('to-field', 'Cash'), findsOneWidget);
    });

    testWithDatabase('cannot swap before the second account is chosen', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tapText(tester, 'Transfer');

      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('swap-accounts')))
            .onPressed,
        isNull,
      );
    });

    testWithDatabase('asks for the account the money goes to', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tapText(tester, 'Transfer');

      await typeAmount(tester, '500');
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
      await openAddForm(tester);
      await tapText(tester, 'Transfer');
      await chooseAccount(tester, field: 'to-field', id: b.bkash);
      await typeAmount(tester, '500');
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
      await openAddForm(tester);

      await tapText(tester, 'Transfer');

      expect(find.text('You need two accounts'), findsOneWidget);
    });
  });

  group('empty states', () {
    testWithDatabase('ask for an account first', (tester, db) async {
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(find.text('Add an account first'), findsOneWidget);

      await tapText(tester, 'Add account');
      expect(appBarTitle('New account'), findsOneWidget);
    });

    testWithDatabase('offer to add a category when there is none', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('category-field')));
      await tester.pumpAndSettle();

      expect(find.text('There are no categories yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-empty-add')), findsOneWidget);
    });
  });
}
