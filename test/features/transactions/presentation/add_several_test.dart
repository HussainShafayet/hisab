import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillAmount(WidgetTester tester, int row, String text) async {
  final finder = find.byKey(ValueKey('row-amount-$row'));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<void> chooseCategoryOfRow(WidgetTester tester, int row, int id) async {
  await tapKey(tester, 'row-category-$row');
  await tester.tap(find.byKey(ValueKey('category-option-$id')));
  await tester.pumpAndSettle();
}

Future<void> chooseAccountOfRow(
  WidgetTester tester, {
  required String field,
  required int id,
}) async {
  await tapKey(tester, field);
  await tester.tap(find.byKey(ValueKey('account-option-$id')));
  await tester.pumpAndSettle();
}

Future<void> openAddSeveral(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-several')));
  await tester.pumpAndSettle();
}

Finder saveButtonText(String text) => find.descendant(
  of: find.byKey(const ValueKey('save-all')),
  matching: find.text(text),
);

bool saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('save-all'))).enabled;

Future<List<TransactionRow>> savedRows(AppDatabase db) =>
    db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

void main() {
  group('Add several', () {
    testWithDatabase('opens from Add transaction with one row, Save off', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      expect(find.text('Add several'), findsWidgets);
      expect(find.text('Row 1 · Expense'), findsOneWidget);
      expect(find.byKey(const ValueKey('row-title-1')), findsNothing);
      // Nothing to remove while there is only one row.
      expect(find.byKey(const ValueKey('row-remove-0')), findsNothing);
      expect(saveButtonText('Save'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWithDatabase('saves one row and closes', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await fillAmount(tester, 0, '120');
      await chooseCategoryOfRow(tester, 0, b.food);
      expect(saveEnabled(tester), isTrue);
      await tapKey(tester, 'save-all');

      final rows = await savedRows(db);
      expect(rows, hasLength(1));
      expect(rows.single.amount, 12000);
      expect(rows.single.categoryId, b.food);
      // Both screens are gone, and the message says what happened.
      expect(find.byKey(const ValueKey('save-all')), findsNothing);
      expect(find.byKey(const ValueKey('add-several')), findsNothing);
      expect(find.text('1 transaction saved'), findsOneWidget);
    });

    testWithDatabase('saves a mix of types and accounts with one tap', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await fillAmount(tester, 0, '100');
      await chooseCategoryOfRow(tester, 0, b.food);

      // A new row starts like the one before: an expense from the same account.
      await tapKey(tester, 'add-row');
      expect(find.text('Row 2 · Expense'), findsOneWidget);
      await fillAmount(tester, 1, '40');
      await chooseCategoryOfRow(tester, 1, b.transport);
      await chooseAccountOfRow(tester, field: 'row-account-1', id: b.bkash);

      await tapKey(tester, 'add-row');
      await tester.tap(find.text('Income').last);
      await tester.pumpAndSettle();
      expect(find.text('Row 3 · Income'), findsOneWidget);
      await fillAmount(tester, 2, '2000');
      await chooseCategoryOfRow(tester, 2, b.salary);

      expect(saveButtonText('Save all 3'), findsOneWidget);
      await tapKey(tester, 'save-all');

      final rows = await savedRows(db);
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.type), contains(TransactionType.income));
      final bkashRow = rows.singleWhere((r) => r.amount == 4000);
      expect(bkashRow.accountId, b.bkash);
      expect(find.text('3 transactions saved'), findsOneWidget);
    });

    testWithDatabase('saves a transfer row between two accounts', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await tester.tap(find.text('Transfer').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row-category-0')), findsNothing);
      await fillAmount(tester, 0, '500');
      await chooseAccountOfRow(tester, field: 'row-from-0', id: b.cash);
      await chooseAccountOfRow(tester, field: 'row-to-0', id: b.bkash);
      await tapKey(tester, 'save-all');

      final rows = await savedRows(db);
      expect(rows.single.type, TransactionType.transfer);
      expect(rows.single.accountId, b.cash);
      expect(rows.single.toAccountId, b.bkash);
    });

    testWithDatabase('skips blank rows and does not count them', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await tapKey(tester, 'add-row');
      await tapKey(tester, 'add-row');
      await fillAmount(tester, 1, '70');
      await chooseCategoryOfRow(tester, 1, b.food);

      expect(saveButtonText('Save'), findsOneWidget);
      await tapKey(tester, 'save-all');

      expect(await savedRows(db), hasLength(1));
      expect(find.text('1 transaction saved'), findsOneWidget);
    });

    testWithDatabase('keeps a bad row, saves the others, and fixes it later', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await fillAmount(tester, 0, '100');
      await chooseCategoryOfRow(tester, 0, b.food);
      await tapKey(tester, 'add-row');
      // The second row has an amount but no category.
      await fillAmount(tester, 1, '55');
      expect(saveButtonText('Save all 2'), findsOneWidget);
      await tapKey(tester, 'save-all');

      // The good row was saved and left; the bad one stays with its reason.
      expect((await savedRows(db)).map((r) => r.amount), [10000]);
      expect(find.byKey(const ValueKey('save-all')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('batch-banner'))).data,
        '1 saved, 1 left to fix',
      );
      expect(find.text('Row 1 · Expense'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('row-error-0'))).data,
        'Choose a category.',
      );
      expect(saveButtonText('Save'), findsOneWidget);

      // Fixing it and saving again adds only that row: no duplicate.
      await chooseCategoryOfRow(tester, 0, b.transport);
      expect(find.byKey(const ValueKey('row-error-0')), findsNothing);
      await tapKey(tester, 'save-all');

      final rows = await savedRows(db);
      expect(rows.map((r) => r.amount), unorderedEquals([10000, 5500]));
      expect(find.text('1 transaction saved'), findsOneWidget);
    });

    testWithDatabase('says nothing was saved when every row is bad', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await fillAmount(tester, 0, '100');
      await tapKey(tester, 'save-all');

      expect(await savedRows(db), isEmpty);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('batch-banner'))).data,
        '1 row needs fixing',
      );
    });

    testWithDatabase('removes a row', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await tapKey(tester, 'add-row');
      expect(find.text('Row 2 · Expense'), findsOneWidget);
      await tapKey(tester, 'row-remove-1');
      expect(find.text('Row 2 · Expense'), findsNothing);
      expect(find.byKey(const ValueKey('row-remove-0')), findsNothing);
    });
  });

  group('Paste lines', () {
    Future<void> pasteLines(WidgetTester tester, String text) async {
      await tapKey(tester, 'paste-lines');
      await tester.enterText(find.byKey(const ValueKey('paste-field')), text);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('paste-add')));
      await tester.pumpAndSettle();
    }

    testWithDatabase('makes a row of each line, and they can be saved', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await pasteLines(tester, 'transport 50\nfood 120 bkash\n+salary 30k');

      // The empty first row gave way, so there are three rows.
      expect(find.text('Added 3 rows. Check them and save.'), findsOneWidget);
      expect(find.byKey(const ValueKey('row-amount-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('row-amount-3')), findsNothing);
      expect(saveButtonText('Save all 3'), findsOneWidget);

      await tapKey(tester, 'save-all');

      final rows = await savedRows(db);
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.amount).toList()..sort(), [
        5000,
        12000,
        3000000,
      ]);
      final byAmount = {for (final r in rows) r.amount: r};
      expect(byAmount[5000]!.categoryId, b.transport);
      expect(byAmount[5000]!.accountId, b.cash);
      expect(byAmount[12000]!.categoryId, b.food);
      expect(byAmount[12000]!.accountId, b.bkash);
      expect(byAmount[3000000]!.type, TransactionType.income);
      expect(byAmount[3000000]!.categoryId, b.salary);
    });

    testWithDatabase('keeps the rows that were already filled in', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);
      await fillAmount(tester, 0, '777');

      await pasteLines(tester, 'food 120');

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('row-amount-0')))
            .controller!
            .text,
        '777',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('row-amount-1')))
            .controller!
            .text,
        '120',
      );
      expect(find.text('Added 1 row. Check it and save.'), findsOneWidget);
    });

    testWithDatabase('a line with no amount makes a row to finish', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await pasteLines(tester, 'transport');
      await tapKey(tester, 'save-all');

      // The row stays, with its reason; nothing was saved.
      expect(await savedRows(db), isEmpty);
      expect(find.text('Enter an amount.'), findsOneWidget);
    });

    testWithDatabase('says so when no line has anything in it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await pasteLines(tester, '৳ \n ৳');

      expect(
        find.text('Nothing to add: write one entry on each line.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('row-amount-1')), findsNothing);
    });

    testWithDatabase('Add rows is off until something is written', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await tapKey(tester, 'paste-lines');

      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('paste-add')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paste-field')), findsNothing);
    });

    testWithDatabase('the clipboard can be pasted into the box', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': 'food 80\nfood 90'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await tapKey(tester, 'paste-lines');
      await tester.tap(find.byKey(const ValueKey('paste-clipboard')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('paste-field')))
            .controller!
            .text,
        'food 80\nfood 90',
      );
      await tester.tap(find.byKey(const ValueKey('paste-add')));
      await tester.pumpAndSettle();
      expect(saveButtonText('Save all 2'), findsOneWidget);
    });
  });
}
