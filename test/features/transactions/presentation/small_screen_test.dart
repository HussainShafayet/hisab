import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/fonts.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// A small phone, 360 x 640 logical pixels.
void useSmallPhone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
}

void main() {
  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the add form fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await insertTestAccount(db, name: 'Cash');
      await insertTestAccount(db, name: 'bKash');
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Overflows are reported as exceptions, which fail the test.
      expect(tester.takeException(), isNull);
      final screen = tester.view.physicalSize;
      for (final label in ['Save', 'Save & add another']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: label);
        expect(rect.right, lessThanOrEqualTo(screen.width), reason: label);
      }
      // The keypad is fully visible too.
      expect(
        tester.getRect(find.byKey(const ValueKey('key-+'))).bottom,
        lessThanOrEqualTo(screen.height),
      );
    }, seedDefaults: true);
  }

  testWithDatabase('a full add flow works on a small phone', (
    tester,
    db,
  ) async {
    useSmallPhone(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    for (final key in '250'.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$key')));
    }
    await tester.ensureVisible(find.byKey(ValueKey('category-${b.food}')));
    await tester.tap(find.byKey(ValueKey('category-${b.food}')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rows = await db.transactionsDao.getBetween(
      DateTime(2000),
      DateTime(2100),
    );
    expect(rows.single.amount, 25000);
  });

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the transaction list fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 5000000000,
        accountId: b.cash,
        categoryId: b.salary,
        date: DateTime(2026, 10, 11, 9),
        note: 'A very long note about the salary that must not break the row',
      );
      await addTransaction(
        db,
        type: TransactionType.transfer,
        amount: 123456789,
        accountId: b.cash,
        toAccountId: b.bkash,
        date: DateTime(2026, 10, 10, 9),
      );
      await pumpAppWithDatabase(tester, db);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('+৳5,00,00,000.00'), findsWidgets);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the accounts list fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'A savings account with a rather long name',
          type: AccountType.bank,
          openingBalance: const Value(-5000000000),
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(tester.takeException(), isNull);
      expect(find.text('-৳5,00,00,000.00'), findsWidgets);
    });
  }

  group('layout on a 360 dp wide phone', () {
    testWithDatabase('bottom bar labels stay on one line', (tester, db) async {
      useSmallPhone(tester);
      await tester.runAsync(loadRealFonts);
      await pumpAppWithDatabase(tester, db);

      for (final label in [
        'Home',
        'Transactions',
        'Budget',
        'Reports',
        'More',
      ]) {
        final size = tester.getSize(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        expect(size.height, lessThan(18), reason: '$label wraps');
      }
    });

    testWithDatabase('the filter sheet is not covered by the add button', (
      tester,
      db,
    ) async {
      useSmallPhone(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();

      // A tap that lands on something else, like the add button, fails.
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Filter'), findsNothing);
    });

    testWithDatabase('day totals sit at the right edge', (tester, db) async {
      useSmallPhone(tester);
      await tester.runAsync(loadRealFonts);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 41000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 11, 12),
      );
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      final total = find.descendant(
        of: find.byType(DayHeader),
        matching: find.text('-৳410.00'),
      );
      expect(tester.getRect(total).right, closeTo(360 - 16, 1));
    });

    testWithDatabase('the save buttons stay on one line', (tester, db) async {
      useSmallPhone(tester);
      await tester.runAsync(loadRealFonts);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      for (final label in ['Save', 'Save & add another']) {
        expect(
          tester.getSize(find.text(label)).height,
          lessThan(24),
          reason: label,
        );
      }
    });

    testWithDatabase(
      'category chips are short, and add the parent only when needed',
      (tester, db) async {
        useSmallPhone(tester);
        await insertTestAccount(db, name: 'Cash');
        final food = await insertTestCategory(db, name: 'Food');
        final shopping = await insertTestCategory(db, name: 'Shopping');
        await insertTestCategory(db, name: 'Groceries', parentId: food);
        await insertTestCategory(db, name: 'Other', parentId: food);
        await insertTestCategory(db, name: 'Other', parentId: shopping);
        await pumpAppWithDatabase(tester, db);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Groceries'), findsOneWidget);
        expect(find.text('Food › Groceries'), findsNothing);
        // Two sub-categories are called "Other", so both say where they belong.
        expect(find.text('Food › Other'), findsOneWidget);
        expect(find.text('Shopping › Other'), findsOneWidget);
      },
    );
  });

  group('on a short window (phone turned sideways, split screen)', () {
    void useShortWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWithDatabase('the add form scrolls instead of overflowing', (
      tester,
      db,
    ) async {
      useShortWindow(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // An overflow is reported as an exception.
      expect(tester.takeException(), isNull);
    });

    testWithDatabase('a transaction can be saved from start to finish', (
      tester,
      db,
    ) async {
      useShortWindow(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The form is one long list here, so scroll to each part like a user.
      // The Note text field has a Scrollable of its own: take the outer one.
      final formList = find.byType(Scrollable).first;
      await tester.ensureVisible(find.byKey(ValueKey('category-${b.food}')));
      await tester.tap(find.byKey(ValueKey('category-${b.food}')));
      await tester.pump();
      for (final key in '75'.split('')) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('key-$key')),
          100,
          scrollable: formList,
        );
        await tester.tap(find.byKey(ValueKey('key-$key')));
      }
      await tester.scrollUntilVisible(
        find.text('Save'),
        100,
        scrollable: formList,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final rows = await db.transactionsDao.getBetween(
        DateTime(2000),
        DateTime(2100),
      );
      expect(rows.single.amount, 7500);
    });

    testWithDatabase('the transfer form fits too', (tester, db) async {
      useShortWindow(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Transfer'));
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the budget screen fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await tester.runAsync(loadRealFonts);
      final b = await seedBasics(db);
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(month: '2026-10', amount: 5000000000),
      );
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          amount: 100,
          categoryId: Value(b.food),
        ),
      );
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 123456789,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      await pumpAppWithDatabase(tester, db);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Budget'),
        ),
      );
      await tester.pumpAndSettle();

      // An overflow or a ListTile layout failure is reported as an exception.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('overall-budget')), findsOneWidget);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('Home and Reports fit a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await tester.runAsync(loadRealFonts);
      final b = await seedBasics(db);
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(month: '2026-10', amount: 5000000000),
      );
      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 5000000000,
        accountId: b.cash,
        categoryId: b.salary,
        date: DateTime(2026, 10, 1),
        note: 'A very long note about the salary that must not break a row',
      );
      for (final category in [b.food, b.transport]) {
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 123456789,
          accountId: b.cash,
          categoryId: category,
          date: DateTime(2026, 10, 11, 9),
        );
      }
      await pumpAppWithDatabase(tester, db);

      // Home is the first tab.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('budget-ring')), findsOneWidget);
      // Scroll to the bottom of Home, where the recent transactions are.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Reports'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase(
      'Backup and the CSV import fit a small phone (text x$scale)',
      (tester, db) async {
        useSmallPhone(tester, textScale: scale);
        await tester.runAsync(loadRealFonts);
        await seedBasics(db);
        final gateway = FakeFileGateway()
          ..pickText(
            'a-sheet-with-a-rather-long-file-name-for-the-month-of-october.csv',
            'Transaction date,A very long description column name,Category,Total amount (BDT),Paid from\n'
                '11/10/2026,বাজার করলাম অনেক কিছু একসাথে,Food,"-৳50,00,00,000.50",bKash personal wallet\n'
                '12/10/2026,Rent for the whole month of October,Rent,-12000,Cash\n'
                'not a date,Broken,Food,-5,Cash\n',
          );
        await pumpAppWithDatabase(
          tester,
          db,
          overrides: [fileGatewayProvider.overrideWithValue(gateway)],
        );

        await openFromMore(tester, 'Backup & export');
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('import-csv')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Choose CSV file'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The map step is a long list: look at the end of it too.
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
