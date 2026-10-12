import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

/// Opens the Transactions tab with this data (today is Sunday 11 Oct 2026):
///
/// * today      expense  ৳250.00  Food       Cash   "Lunch with Rahim"
/// * today      income   ৳50,000  Salary     Cash
/// * yesterday  expense  ৳80.00   Transport  bKash  "Rickshaw"
/// * Fri 9 Oct transfer  ৳1,000   Cash → bKash
/// * 28 Sep     expense  ৳500.00  Food       Cash
class MonthData {
  const MonthData({
    required this.basics,
    required this.lunch,
    required this.salary,
    required this.rickshaw,
    required this.transfer,
    required this.september,
  });

  final Basics basics;
  final int lunch;
  final int salary;
  final int rickshaw;
  final int transfer;
  final int september;
}

Future<MonthData> seedMonth(AppDatabase db) async {
  final b = await seedBasics(db);
  return MonthData(
    basics: b,
    lunch: await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 25000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 11, 12),
      note: 'Lunch with Rahim',
    ),
    salary: await addTransaction(
      db,
      type: TransactionType.income,
      amount: 5000000,
      accountId: b.cash,
      categoryId: b.salary,
      date: DateTime(2026, 10, 11, 9),
    ),
    rickshaw: await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 8000,
      accountId: b.bkash,
      categoryId: b.transport,
      date: DateTime(2026, 10, 10, 18),
      note: 'Rickshaw',
    ),
    transfer: await addTransaction(
      db,
      type: TransactionType.transfer,
      amount: 100000,
      accountId: b.cash,
      toAccountId: b.bkash,
      date: DateTime(2026, 10, 9, 10),
    ),
    september: await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 50000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 9, 28, 20),
    ),
  );
}

Future<void> openTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Transactions'),
    ),
  );
  await tester.pumpAndSettle();
}

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Finder row(int id) => find.byKey(ValueKey('transaction-$id'));

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<List<TransactionRow>> savedRows(AppDatabase db) =>
    db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

void main() {
  group('the month', () {
    testWithDatabase('groups transactions by day with daily totals', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Fri, 9 Oct'), findsOneWidget);
      // Today: +50,000.00 and -250.00, both in the header and on the rows.
      expect(find.text('+৳50,000.00'), findsNWidgets(2));
      expect(find.text('-৳250.00'), findsNWidgets(2));
      // Yesterday: -80.00.
      expect(find.text('-৳80.00'), findsNWidgets(2));
      // September is not shown.
      expect(find.text('-৳500.00'), findsNothing);
    });

    testWithDatabase('shows the month summary without transfers', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(find.text('৳50,000.00'), findsOneWidget); // income
      expect(find.text('৳330.00'), findsOneWidget); // expense 250 + 80
      expect(find.text('৳49,670.00'), findsOneWidget); // balance
    });

    testWithDatabase('shows what each row is', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
      expect(find.text('bKash · Rickshaw'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Cash → bKash'), findsOneWidget);
      expect(find.text('৳1,000.00'), findsOneWidget); // neutral transfer amount
    });

    testWithDatabase('switches months and cannot go past this one', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      IconButton next() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next().onPressed, isNull);

      await tester.tap(find.byTooltip('Previous month'));
      await settle(tester);

      expect(find.text('September 2026'), findsOneWidget);
      // The day header, the row and the (negative) balance in the summary.
      expect(find.text('-৳500.00'), findsNWidgets(3));
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);
      expect(next().onPressed, isNotNull);

      await tester.tap(find.byTooltip('Previous month'));
      await settle(tester);
      expect(find.text('No transactions in August 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Next month'));
      await tester.tap(find.byTooltip('Next month'));
      await settle(tester);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
    });

    testWithDatabase('has an empty state that leads to the add form', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(find.text('No transactions in October 2026'), findsOneWidget);

      await tapText(tester, 'Add transaction');

      expect(appBarTitle('Add transaction'), findsOneWidget);
    });

    testWithDatabase('updates by itself when a transaction is added', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      expect(find.text('Food'), findsNothing);

      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 12300,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 11, 8),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      // The day header, the row and the (negative) balance in the summary.
      expect(find.text('-৳123.00'), findsNWidgets(3));
    });
  });

  group('balance adjustments', () {
    testWithDatabase('are shown as corrections and left out of the totals', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.income,
          amount: 20000,
          accountId: d.basics.cash,
          categoryId: Value(d.basics.salary),
          date: DateTime(2026, 10, 11, 13),
          isAdjustment: const Value(true),
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(
        find.text('Cash · Balance fix, not in your totals'),
        findsOneWidget,
      );
      // The row is there, in the neutral color with its sign.
      expect(find.text('+৳200.00'), findsOneWidget);
      // The summary and the day header still show the real numbers only.
      expect(find.text('৳50,000.00'), findsOneWidget);
      expect(find.text('+৳50,000.00'), findsNWidgets(2));
      expect(find.text('৳330.00'), findsOneWidget);
    });
  });

  group('search', () {
    testWithDatabase('finds by note and by amount', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'rickshaw');
      await settle(tester);

      expect(find.text('bKash · Rickshaw'), findsOneWidget);
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);
      expect(find.text('Transfer'), findsNothing);

      await tester.enterText(find.byType(TextField), '250');
      await settle(tester);

      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
      expect(find.text('bKash · Rickshaw'), findsNothing);
    });

    testWithDatabase('also matches the category name', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'salary');
      await settle(tester);

      expect(find.text('+৳50,000.00'), findsNWidgets(2));
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);
    });

    testWithDatabase('says when nothing matches and can start over', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(tester);

      expect(find.text('No results'), findsOneWidget);

      await tapText(tester, 'Clear filters');

      expect(find.text('No results'), findsNothing);
      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWithDatabase('closing the search shows everything again', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'rickshaw');
      await settle(tester);

      await tester.tap(find.byTooltip('Close search'));
      await settle(tester);

      expect(appBarTitle('Transactions'), findsOneWidget);
      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
      expect(find.text('bKash · Rickshaw'), findsOneWidget);
    });
  });

  group('filters', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseFromDropdown(
      WidgetTester tester, {
      required int dropdown,
      required String option,
    }) async {
      await tester.tap(find.byType(DropdownButtonFormField<int?>).at(dropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWithDatabase('by type', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await openSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
      await tester.pump();
      await tapText(tester, 'Apply');

      expect(find.text('+৳50,000.00'), findsNWidgets(2));
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);
      expect(find.text('Transfer'), findsNothing);
      // The filter button shows how many options are set.
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWithDatabase('by category and account together', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await openSheet(tester);
      await chooseFromDropdown(tester, dropdown: 0, option: 'Transport');
      await chooseFromDropdown(tester, dropdown: 1, option: 'bKash');
      await tapText(tester, 'Apply');

      expect(find.text('bKash · Rickshaw'), findsOneWidget);
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWithDatabase('by account includes transfers into it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await openSheet(tester);
      await chooseFromDropdown(tester, dropdown: 1, option: 'bKash');
      await tapText(tester, 'Apply');

      expect(find.text('bKash · Rickshaw'), findsOneWidget);
      expect(find.text('Cash → bKash'), findsOneWidget);
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);
    });

    testWithDatabase('by a date range, replacing the month', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await openSheet(tester);
      await tapText(tester, 'Any date');
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tapText(tester, 'Save');
      await tapText(tester, 'Apply');

      // 5 to 9 Oct: only the transfer on Friday the 9th.
      expect(find.text('5 Oct 2026 – 9 Oct 2026'), findsOneWidget);
      expect(find.byTooltip('Previous month'), findsNothing);
      expect(find.text('Cash → bKash'), findsOneWidget);
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);
      expect(find.text('bKash · Rickshaw'), findsNothing);

      await tester.tap(find.byTooltip('Clear date range'));
      await settle(tester);

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
    });

    testWithDatabase('can be cleared in one go', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      await openSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Transfer'));
      await tester.pump();
      await tapText(tester, 'Apply');
      expect(find.text('Cash · Lunch with Rahim'), findsNothing);

      await openSheet(tester);
      await tapText(tester, 'Clear all');

      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsNothing,
      );
    });

    testWithDatabase('keeps the search text when the sheet is applied', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'lunch');
      await settle(tester);

      await openSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expense'));
      await tester.pump();
      await tapText(tester, 'Apply');

      expect(find.text('Cash · Lunch with Rahim'), findsOneWidget);
      expect(find.text('bKash · Rickshaw'), findsNothing);
    });
  });

  group('deleting', () {
    testWithDatabase('swipe left deletes and Undo brings it back', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      final before = (await db.transactionsDao.getById(d.lunch))!;

      await tester.drag(row(d.lunch), const Offset(-600, 0));
      await settle(tester);

      expect(row(d.lunch), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(await db.transactionsDao.getById(d.lunch), isNull);
      // The summary no longer counts it: only the 80 rickshaw is left.
      expect(find.text('৳80.00'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);

      expect(row(d.lunch), findsOneWidget);
      final after = (await db.transactionsDao.getById(d.lunch))!;
      expect(after.id, before.id);
      expect(after.amount, before.amount);
      expect(after.note, before.note);
      expect(after.createdAt, before.createdAt);
      expect(find.text('৳330.00'), findsOneWidget);
    });

    testWithDatabase('can delete from the long-press menu', (tester, db) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.longPress(row(d.rickshaw));
      await settle(tester);
      await tapText(tester, 'Delete');

      expect(row(d.rickshaw), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(await db.transactionsDao.getById(d.rickshaw), isNull);
    });

    testWithDatabase('deleting the last one of the day removes its header', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      expect(find.text('Yesterday'), findsOneWidget);

      await tester.drag(row(d.rickshaw), const Offset(-600, 0));
      await settle(tester);

      expect(find.text('Yesterday'), findsNothing);
    });
  });

  group('editing', () {
    testWithDatabase('tap a row to change it', (tester, db) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);
      final created = (await db.transactionsDao.getById(d.lunch))!.createdAt;

      await tester.tap(row(d.lunch));
      await settle(tester);

      expect(appBarTitle('Edit transaction'), findsOneWidget);
      expect(amountText(tester), '250');
      expect(categoryShown(tester), 'Food');
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Note'))
            .controller!
            .text,
        'Lunch with Rahim',
      );
      expect(find.text('Save & new'), findsNothing);

      await typeAmount(tester, '300');
      await chooseCategory(tester, d.basics.transport);
      await chooseAccount(tester, field: 'account-field', id: d.basics.bkash);
      await tapText(tester, 'Save changes');

      expect(appBarTitle('Transactions'), findsOneWidget);
      final saved = (await db.transactionsDao.getById(d.lunch))!;
      expect(saved.amount, 30000);
      expect(saved.categoryId, d.basics.transport);
      expect(saved.accountId, d.basics.bkash);
      expect(saved.note, 'Lunch with Rahim');
      expect(saved.date, DateTime(2026, 10, 11, 12));
      expect(saved.createdAt, created);
      expect(find.text('bKash · Lunch with Rahim'), findsOneWidget);
    });

    testWithDatabase('keeps the day and time unless the date is changed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.tap(row(d.rickshaw));
      await settle(tester);
      // Rickshaw is from yesterday, so "Yesterday" starts selected.
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('date-yesterday')))
            .selected,
        isTrue,
      );
      await tapText(tester, 'Save changes');
      expect(
        (await db.transactionsDao.getById(d.rickshaw))!.date,
        DateTime(2026, 10, 10, 18),
      );

      await tester.tap(row(d.rickshaw));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('date-today')));
      await tester.pump();
      await tapText(tester, 'Save changes');

      // Moved to today, keeping its 18:00 time of day.
      expect(
        (await db.transactionsDao.getById(d.rickshaw))!.date,
        DateTime(2026, 10, 11, 18),
      );
    });

    testWithDatabase('swipe right opens the editor and the row stays', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.drag(row(d.lunch), const Offset(600, 0));
      await settle(tester);

      expect(appBarTitle('Edit transaction'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(row(d.lunch), findsOneWidget);
      expect(await db.transactionsDao.getById(d.lunch), isNotNull);
    });

    testWithDatabase('a transfer shows both accounts and no fee', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.tap(row(d.transfer));
      await settle(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('from-field')),
          matching: find.text('Cash'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('to-field')),
          matching: find.text('bKash'),
        ),
        findsOneWidget,
      );
      expect(find.text('Fee (optional)'), findsNothing);
    });

    testWithDatabase('a transaction can be turned into a transfer', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.tap(row(d.lunch));
      await settle(tester);
      await tapText(tester, 'Transfer');
      await chooseAccount(tester, field: 'to-field', id: d.basics.bkash);
      await tapText(tester, 'Save changes');

      final saved = (await db.transactionsDao.getById(d.lunch))!;
      expect(saved.type, TransactionType.transfer);
      expect(saved.categoryId, isNull);
      expect(saved.toAccountId, d.basics.bkash);
    });

    testWithDatabase(
      'still opens when its account and category were archived',
      (tester, db) async {
        useTallScreen(tester);
        final d = await seedMonth(db);
        await db.accountsDao.setArchived(d.basics.cash, archived: true);
        await db.categoriesDao.setArchived(d.basics.food, archived: true);
        await pumpAppWithDatabase(tester, db);
        await openTab(tester);

        await tester.tap(row(d.lunch));
        await settle(tester);

        expect(find.text('Archived'), findsOneWidget);
        expect(find.text('Food (archived)'), findsOneWidget);
        await tapText(tester, 'Save changes');
        expect(appBarTitle('Transactions'), findsOneWidget);
      },
    );
  });

  group('duplicating', () {
    testWithDatabase('copies a transaction into the add form, dated today', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.longPress(row(d.rickshaw));
      await settle(tester);
      await tapText(tester, 'Duplicate');

      expect(appBarTitle('Add transaction'), findsOneWidget);
      expect(amountText(tester), '80');
      expect(categoryShown(tester), 'Transport');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-field')),
          matching: find.text('bKash'),
        ),
        findsOneWidget,
      );
      // The original is from yesterday; the copy is for today.
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('date-today')))
            .selected,
        isTrue,
      );
      expect(find.text('Save & new'), findsOneWidget);

      await tapText(tester, 'Save');

      final rows = await savedRows(db);
      final copy = rows.firstWhere(
        (r) => r.id != d.rickshaw && r.note == 'Rickshaw',
      );
      expect(rows, hasLength(6));
      expect(copy.amount, 8000);
      expect(copy.accountId, d.basics.bkash);
      expect(copy.categoryId, d.basics.transport);
      expect(copy.date, DateTime(2026, 10, 11, 14, 30));
      expect(await db.transactionsDao.getById(d.rickshaw), isNotNull);
    });

    testWithDatabase('does not reuse an archived category', (tester, db) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await db.categoriesDao.setArchived(d.basics.transport, archived: true);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      await tester.longPress(row(d.rickshaw));
      await settle(tester);
      await tapText(tester, 'Duplicate');

      // The archived category is not selected, so one has to be chosen.
      expect(categoryShown(tester), 'Choose a category');
    });
  });
}
