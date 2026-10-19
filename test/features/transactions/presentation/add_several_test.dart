import 'package:flutter/material.dart';
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
}
