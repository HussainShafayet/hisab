import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

/// Rows: 1 and 2 are fine; 3 is income in a category that is new; 4 has a
/// date that does not exist; 5 has an amount that is not a number; 6 is the
/// same as 1.
const sheet =
    'Date,Description,Category,Amount,Account\n'
    '11/10/2026,Lunch,Food,-250,Cash\n'
    '12/10/2026,Rickshaw,Transport,-60,Cash\n'
    '13/10/2026,Bonus,Bonus,50000,bKash\n'
    '31/02/2026,Bad date,Food,-10,Cash\n'
    '14/10/2026,Mystery,Pets,abc,Cash\n'
    '11/10/2026,Lunch,Food,-250,Cash\n';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Finder fieldDropdown(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(DropdownButtonFormField<int?>),
);

Future<void> pumpImport(
  WidgetTester tester,
  AppDatabase db,
  FakeFileGateway gateway,
) async {
  useTallScreen(tester);
  await pumpAppWithDatabase(
    tester,
    db,
    overrides: [fileGatewayProvider.overrideWithValue(gateway)],
  );
  await openFromMore(tester, 'Backup & export');
  await tester.tap(find.byKey(const ValueKey('import-csv')));
  await tester.pumpAndSettle();
}

Future<void> chooseFile(WidgetTester tester) async {
  await tester.tap(find.text('Choose CSV file'));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

String countOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// Picks an item of a column dropdown, by what is written on it.
Future<void> pickColumn(WidgetTester tester, String field, Finder item) async {
  await tester.tap(fieldDropdown(field));
  await tester.pumpAndSettle();
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

void main() {
  late FakeFileGateway gateway;

  setUp(() => gateway = FakeFileGateway());

  group('choosing the file', () {
    testWithDatabase('starts by asking for a CSV file', (tester, db) async {
      await seedBasics(db);
      await pumpImport(tester, db, gateway);

      expect(appBarTitle('Import from CSV'), findsOneWidget);
      expect(find.text('Import transactions from a CSV file'), findsOneWidget);
      expect(find.text('Choose CSV file'), findsOneWidget);
    });

    testWithDatabase('asks the system for csv and txt files', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);

      await chooseFile(tester);

      expect(gateway.pickRequests.single, ['csv', 'txt']);
    });

    testWithDatabase('stays here when no file is chosen', (tester, db) async {
      await seedBasics(db);
      gateway.picked = null;
      await pumpImport(tester, db, gateway);

      await chooseFile(tester);

      expect(appBarTitle('Import from CSV'), findsOneWidget);
      expect(find.byKey(const ValueKey('import-error')), findsNothing);
    });

    testWithDatabase('explains a file that is not UTF-8 text', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.picked = PickedFile(
        name: 'x.csv',
        bytes: Uint8List.fromList([0xFF, 0xFE, 0x41, 0x80]),
      );
      await pumpImport(tester, db, gateway);

      await chooseFile(tester);

      expect(find.textContaining('not UTF-8 text'), findsOneWidget);
    });

    testWithDatabase('explains an empty file and a file with only a header', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText('empty.csv', '\n\n');
      await pumpImport(tester, db, gateway);

      await chooseFile(tester);
      expect(find.textContaining('has no rows'), findsOneWidget);

      gateway.pickText('header.csv', 'Date,Amount\n');
      await chooseFile(tester);
      expect(find.textContaining('column names but no rows'), findsOneWidget);
    });

    testWithDatabase('says so when the file cannot be opened', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.failure = Exception('no permission');
      await pumpImport(tester, db, gateway);

      await chooseFile(tester);

      expect(find.textContaining('no permission'), findsOneWidget);
    });
  });

  group('matching the columns', () {
    testWithDatabase(
      'guesses the columns, the date order and where the type comes from',
      (tester, db) async {
        await seedBasics(db);
        gateway.pickText('sheet.csv', sheet);
        await pumpImport(tester, db, gateway);

        await chooseFile(tester);

        expect(appBarTitle('Match your columns'), findsOneWidget);
        expect(find.text('sheet.csv'), findsOneWidget);
        expect(countOf(tester, 'file-summary'), '6 rows, 5 columns');
        int? selected(String label) => tester
            .widget<DropdownButtonFormField<int?>>(fieldDropdown(label))
            .initialValue;
        expect(selected('Date *'), 0);
        expect(selected('Note or description'), 1);
        expect(selected('Category'), 2);
        expect(selected('Amount *'), 3);
        expect(selected('Account'), 4);
        expect(selected('Type (income, expense, transfer)'), isNull);
        expect(
          find.text('The sign of the amount'),
          findsOneWidget,
        ); // negative amounts
        expect(find.text('Day/Month/Year  (11/10/2026)'), findsOneWidget);
        expect(find.byKey(const ValueKey('mapping-problem')), findsNothing);
      },
    );

    testWithDatabase('a column can be changed and cleared', (tester, db) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);

      await pickColumn(tester, 'Amount *', find.text('Choose a column'));

      expect(
        find.text('Choose the column that has the amount.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Preview'))
            .onPressed,
        isNull,
      );

      await pickColumn(tester, 'Amount *', find.textContaining('Amount  ·'));

      expect(find.byKey(const ValueKey('mapping-problem')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Preview'))
            .onPressed,
        isNotNull,
      );
    });

    testWithDatabase('shows what a column holds next to its name', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);

      await tester.tap(fieldDropdown('Category'));
      await tester.pumpAndSettle();

      expect(find.text('Amount  ·  -250'), findsWidgets);
      expect(find.text('Date  ·  11/10/2026'), findsWidgets);
    });

    testWithDatabase(
      'the date order can be changed and shows how the first date reads',
      (tester, db) async {
        await seedBasics(db);
        gateway.pickText(
          'ambiguous.csv',
          'Date,Amount,Account\n10/11/2026,-5,Cash\n',
        );
        await pumpImport(tester, db, gateway);
        await chooseFile(tester);
        expect(find.text('"10/11/2026" is 10 November 2026.'), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<SheetDateFormat>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Month/Day/Year  (10/11/2026)').last);
        await tester.pumpAndSettle();

        expect(find.text('"10/11/2026" is 11 October 2026.'), findsOneWidget);
      },
    );

    testWithDatabase(
      'says when the first date cannot be read in the chosen order',
      (tester, db) async {
        await seedBasics(db);
        gateway.pickText(
          'iso.csv',
          'Date,Amount,Account\n2026-10-11,-5,Cash\n',
        );
        await pumpImport(tester, db, gateway);
        await chooseFile(tester); // detected as year first
        expect(find.text('"2026-10-11" is 11 October 2026.'), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<SheetDateFormat>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Day/Month/Year  (11/10/2026)').last);
        await tester.pumpAndSettle();

        expect(
          find.text('"2026-10-11" cannot be read in this order.'),
          findsOneWidget,
        );
      },
    );

    testWithDatabase('the first row can be treated as data', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);

      await tester.tap(find.byKey(const ValueKey('has-header')));
      await tester.pumpAndSettle();

      expect(countOf(tester, 'file-summary'), '7 rows, 5 columns');
      // The column names are no longer there to guess from.
      expect(find.text('Choose the column that has the date.'), findsOneWidget);
      expect(find.text('Column 1  ·  Date'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('has-header')));
      await tester.pumpAndSettle();

      expect(countOf(tester, 'file-summary'), '6 rows, 5 columns');
      expect(find.byKey(const ValueKey('mapping-problem')), findsNothing);
    });

    testWithDatabase('asks for an account when the file has none', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await db.accountsDao.setArchived(
        (await db.accountsDao.getAll()).first.id,
        archived: true,
      );
      await db.accountsDao.setArchived(
        (await db.accountsDao.getAll()).first.id,
        archived: true,
      );
      gateway.pickText('no-account.csv', 'Date,Amount\n11/10/2026,-5\n');
      await pumpImport(tester, db, gateway);

      await chooseFile(tester);

      expect(
        find.text('Choose the account these transactions belong to.'),
        findsOneWidget,
      );
      expect(find.textContaining('You have no accounts yet'), findsOneWidget);
    });

    testWithDatabase('a type column makes the type come from it', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText(
        'typed.csv',
        'Date,Type,Amount,Account\n11/10/2026,income,500,Cash\n',
      );
      await pumpImport(tester, db, gateway);

      await chooseFile(tester);

      expect(find.text('A column of my file'), findsOneWidget);
      expect(find.byKey(const ValueKey('mapping-problem')), findsNothing);
    });
  });

  group('the preview', () {
    testWithDatabase('says what will happen to every row', (tester, db) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);

      await tapText(tester, 'Preview');

      expect(appBarTitle('Preview'), findsOneWidget);
      expect(countOf(tester, 'count-import'), '4');
      expect(countOf(tester, 'count-duplicates'), '0');
      expect(countOf(tester, 'count-errors'), '2');
      expect(
        find.widgetWithText(FilledButton, 'Import 4 transactions'),
        findsOneWidget,
      );
      // Only the rows that will be imported make new categories.
      expect(find.text('Categories: Bonus'), findsOneWidget);
      // 'Pets' is only in a row that cannot be read, so it is not created.
      expect(find.textContaining('Categories: Bonus, Pets'), findsNothing);
      expect(find.byKey(const ValueKey('plan-row-1')), findsOneWidget);
    });

    testWithDatabase(
      'shows each row with its date, amount, account and category',
      (tester, db) async {
        await seedBasics(db);
        gateway.pickText('sheet.csv', sheet);
        await pumpImport(tester, db, gateway);
        await chooseFile(tester);

        await tapText(tester, 'Preview');

        final first = find.byKey(const ValueKey('plan-row-1'));
        expect(
          find.descendant(of: first, matching: find.text('Expense ৳250.00')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: first,
            matching: find.text('11 Oct 2026 · Cash · Food · Lunch'),
          ),
          findsOneWidget,
        );
        final third = find.byKey(const ValueKey('plan-row-3'));
        expect(
          find.descendant(of: third, matching: find.text('Income ৳50,000.00')),
          findsOneWidget,
        );
      },
    );

    testWithDatabase('says why a row cannot be read', (tester, db) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);

      await tapText(tester, 'Preview');

      final bad = find.byKey(const ValueKey('plan-row-4'));
      expect(
        find.descendant(of: bad, matching: find.text('Row 4')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bad,
          matching: find.textContaining(
            '"31/02/2026" is not a Day/Month/Year date',
          ),
        ),
        findsOneWidget,
      );
      final worse = find.byKey(const ValueKey('plan-row-5'));
      expect(
        find.descendant(
          of: worse,
          matching: find.textContaining('"abc" is not an amount'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('can show only some of the rows', (tester, db) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      await tapText(tester, 'Preview');

      await tapText(tester, 'Cannot be read');
      expect(find.byKey(const ValueKey('plan-row-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-row-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-row-1')), findsNothing);

      await tapText(tester, 'To import');
      expect(find.byKey(const ValueKey('plan-row-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-row-4')), findsNothing);

      await tapText(tester, 'Already in the app');
      expect(find.text('No rows here.'), findsOneWidget);
    });

    testWithDatabase('lists the accounts it will create', (tester, db) async {
      await seedBasics(db);
      gateway.pickText(
        'new-account.csv',
        'Date,Amount,Account,Category\n11/10/2026,-5,Nagad,Food\n12/10/2026,-6,Nagad,Food\n',
      );
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);

      await tapText(tester, 'Preview');

      expect(find.text('Accounts: Nagad'), findsOneWidget);
      expect(find.byKey(const ValueKey('will-create')), findsOneWidget);
    });

    testWithDatabase('Back returns to the columns with them kept', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      await pickColumn(tester, 'Account', find.text('Not in my file'));
      await tapText(tester, 'Preview');

      await tapText(tester, 'Back');

      expect(appBarTitle('Match your columns'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<int?>>(fieldDropdown('Account'))
            .initialValue,
        isNull,
      );
    });

    testWithDatabase('the back button goes back a step, then leaves', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      await tapText(tester, 'Preview');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appBarTitle('Match your columns'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appBarTitle('Import from CSV'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appBarTitle('Backup & export'), findsOneWidget);
    });
  });

  group('importing', () {
    testWithDatabase('saves the rows that can be read and says what it did', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      await tapText(tester, 'Preview');

      await tapText(tester, 'Import 4 transactions');

      expect(appBarTitle('Import finished'), findsOneWidget);
      expect(find.text('Imported 4 transactions'), findsOneWidget);
      expect(find.text('Created 1 category'), findsOneWidget);
      expect(find.text('2 rows skipped, could not be read'), findsOneWidget);
      final rows = await db.transactionsDao.getAll();
      expect(rows.map((t) => (t.type, t.amount)), [
        (TransactionType.expense, 25000),
        (TransactionType.expense, 6000),
        (TransactionType.income, 5000000),
        (TransactionType.expense, 25000),
      ]);
      expect(rows[2].accountId, b.bkash);
      final bonus = (await db.categoriesDao.getAll()).firstWhere(
        (c) => c.name == 'Bonus',
      );
      expect(bonus.type, CategoryType.income);
      expect(rows[0].categoryId, b.food);
    });

    testWithDatabase(
      'importing the same file again finds every row already there',
      (tester, db) async {
        await seedBasics(db);
        gateway.pickText('sheet.csv', sheet);
        await pumpImport(tester, db, gateway);
        await chooseFile(tester);
        await tapText(tester, 'Preview');
        await tapText(tester, 'Import 4 transactions');
        await tapText(tester, 'Done');
        expect(appBarTitle('Backup & export'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('import-csv')));
        await tester.pumpAndSettle();
        await chooseFile(tester);
        await tapText(tester, 'Preview');

        expect(countOf(tester, 'count-import'), '0');
        expect(countOf(tester, 'count-duplicates'), '4');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Import 0 transactions'),
              )
              .onPressed,
          isNull,
        );
        expect(await db.transactionsDao.getAll(), hasLength(4));
      },
    );

    testWithDatabase('a different type source changes the rows', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      gateway.pickText(
        'sheet.csv',
        'Date,Amount,Account,Category\n11/10/2026,250,Cash,Food\n',
      );
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      expect(find.text('All rows are expenses'), findsOneWidget);

      await tester.tap(find.text('All rows are expenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All rows are income').last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Preview');

      expect(find.text('Income ৳250.00'), findsOneWidget);
    });

    testWithDatabase('rows with no category go to Other', (tester, db) async {
      await seedBasics(db);
      gateway.pickText(
        'nocat.csv',
        'Date,Amount,Account\n11/10/2026,-5,Cash\n',
      );
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      await tapText(tester, 'Preview');
      expect(find.text('Categories: Other'), findsOneWidget);

      await tapText(tester, 'Import 1 transaction');

      final other = (await db.categoriesDao.getAll()).firstWhere(
        (c) => c.name == 'Other',
      );
      expect((await db.transactionsDao.getAll()).single.categoryId, other.id);
    });

    testWithDatabase('a failure imports nothing and says so', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      final longName = 'A' * 100;
      gateway.pickText(
        'long.csv',
        'Date,Amount,Account,Category\n11/10/2026,-5,$longName,Food\n',
      );
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      await tapText(tester, 'Preview');

      await tapText(tester, 'Import 1 transaction');

      expect(find.textContaining('Nothing was imported'), findsOneWidget);
      expect(appBarTitle('Preview'), findsOneWidget);
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(await db.accountsDao.getAll(), hasLength(2));
    });

    testWithDatabase('See transactions opens the list', (tester, db) async {
      await seedBasics(db);
      gateway.pickText('sheet.csv', sheet);
      await pumpImport(tester, db, gateway);
      await chooseFile(tester);
      await tapText(tester, 'Preview');
      await tapText(tester, 'Import 4 transactions');

      await tapText(tester, 'See transactions');

      expect(appBarTitle('Transactions'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWithDatabase(
      'the app\'s own CSV export can be imported back, and is all duplicates',
      (tester, db) async {
        final b = await seedBasics(db);
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 25000,
          accountId: b.cash,
          categoryId: b.food,
          date: DateTime(2026, 10, 3, 12),
          note: 'Lunch',
        );
        await addTransaction(
          db,
          type: TransactionType.transfer,
          amount: 100000,
          accountId: b.cash,
          toAccountId: b.bkash,
          date: DateTime(2026, 10, 4, 12),
        );
        gateway.pickText(
          'export.csv',
          await BackupRepository(db).exportTransactionsCsv(),
        );
        await pumpImport(tester, db, gateway);
        await chooseFile(tester);

        // Every column is found without any help.
        expect(find.byKey(const ValueKey('mapping-problem')), findsNothing);
        expect(find.text('A column of my file'), findsOneWidget);
        await tapText(tester, 'Preview');

        expect(countOf(tester, 'count-duplicates'), '2');
        expect(countOf(tester, 'count-import'), '0');
        expect(countOf(tester, 'count-errors'), '0');
      },
    );
  });
}
