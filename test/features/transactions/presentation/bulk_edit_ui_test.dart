import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';

import '../../../helpers/pump_app.dart';
import 'transactions_screen_test.dart'
    show MonthData, appBarTitle, openTab, row, savedRows, seedMonth;

// Today is Sunday 11 Oct 2026. October has four rows: lunch (expense, Food,
// Cash), salary (income, Cash), rickshaw (expense, Transport, bKash) and a
// transfer.

Future<void> startSelecting(WidgetTester tester, int id) async {
  await tester.longPress(row(id));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('action-select')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

String countText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('selection-count'))).data!;

Future<MonthData> openMonth(WidgetTester tester, db) async {
  useTallScreen(tester);
  final d = await seedMonth(db);
  await pumpAppWithDatabase(tester, db);
  await openTab(tester);
  return d;
}

void main() {
  group('choosing several rows', () {
    testWithDatabase('starts from a long press and counts what is picked', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      expect(find.byType(Dismissible), findsWidgets);

      await startSelecting(tester, d.lunch);

      expect(countText(tester), '1 selected');
      // No swiping while choosing.
      expect(find.byType(Dismissible), findsNothing);

      await tester.tap(row(d.rickshaw));
      await tester.pumpAndSettle();
      expect(countText(tester), '2 selected');

      await tester.tap(row(d.rickshaw));
      await tester.pumpAndSettle();
      expect(countText(tester), '1 selected');
    });

    testWithDatabase('a long press picks and unpicks too', (tester, db) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);

      await tester.longPress(row(d.salary));
      await tester.pumpAndSettle();
      expect(countText(tester), '2 selected');
      await tester.longPress(row(d.salary));
      await tester.pumpAndSettle();
      expect(countText(tester), '1 selected');
    });

    testWithDatabase('select all picks what the screen shows', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);

      await tapKey(tester, 'selection-all');

      // The four rows of October; the September one is on another month.
      expect(countText(tester), '4 selected');
    });

    testWithDatabase('the cross leaves choosing', (tester, db) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);

      await tapKey(tester, 'selection-close');

      expect(find.byKey(const ValueKey('selection-count')), findsNothing);
      expect(appBarTitle('Transactions'), findsOneWidget);
      expect(find.byType(Dismissible), findsWidgets);
    });

    testWithDatabase('back leaves choosing before it leaves the screen', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selection-count')), findsNothing);
      expect(appBarTitle('Transactions'), findsOneWidget);
    });

    testWithDatabase('the actions wait until something is picked', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);
      bool enabled(String key) =>
          tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed !=
          null;
      expect(enabled('selection-delete'), isTrue);

      await tester.tap(row(d.lunch));
      await tester.pumpAndSettle();

      expect(countText(tester), '0 selected');
      expect(enabled('selection-delete'), isFalse);
      expect(enabled('selection-category'), isFalse);
      expect(enabled('selection-account'), isFalse);
    });
  });

  group('deleting several', () {
    testWithDatabase('asks first, then deletes and offers Undo', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);
      await tester.tap(row(d.rickshaw));
      await tester.pumpAndSettle();

      await tapKey(tester, 'selection-delete');
      expect(find.text('Delete 2 transactions?'), findsOneWidget);
      await tapKey(tester, 'confirm-bulk-delete');

      final ids = (await savedRows(db)).map((t) => t.id);
      expect(ids, isNot(contains(d.lunch)));
      expect(ids, isNot(contains(d.rickshaw)));
      expect(ids, contains(d.salary));
      expect(find.text('2 transactions deleted'), findsOneWidget);
      // Choosing is over.
      expect(find.byKey(const ValueKey('selection-count')), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final back = (await savedRows(db)).map((t) => t.id);
      expect(back, containsAll([d.lunch, d.rickshaw]));
      expect(row(d.lunch), findsOneWidget);
    });

    testWithDatabase('Cancel keeps everything', (tester, db) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);

      await tapKey(tester, 'selection-delete');
      expect(find.text('Delete 1 transaction?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await savedRows(db), hasLength(5));
      expect(countText(tester), '1 selected');
    });
  });

  group('changing the category of several', () {
    testWithDatabase('moves them and can be undone', (tester, db) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);
      await tester.tap(row(d.rickshaw));
      await tester.pumpAndSettle();

      await tapKey(tester, 'selection-category');
      expect(find.text('Move 2 transactions to'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(CategoryPickerSheet),
              matching: find.text('Food'),
            )
            .first,
      );
      await tester.pumpAndSettle();

      final rows = {for (final t in await savedRows(db)) t.id: t};
      expect(rows[d.lunch]!.categoryId, d.basics.food);
      expect(rows[d.rickshaw]!.categoryId, d.basics.food);
      expect(find.text('2 transactions moved to Food'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final undone = {for (final t in await savedRows(db)) t.id: t};
      expect(undone[d.rickshaw]!.categoryId, d.basics.transport);
    });

    testWithDatabase('income and expense together are explained, not changed', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);
      await tester.tap(row(d.salary));
      await tester.pumpAndSettle();

      await tapKey(tester, 'selection-category');

      expect(
        find.textContaining('Pick only expenses, or only income'),
        findsOneWidget,
      );
      expect(find.byType(CategoryPickerSheet), findsNothing);
    });

    testWithDatabase('a transfer in the picks is explained too', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);
      await tester.tap(row(d.transfer));
      await tester.pumpAndSettle();

      await tapKey(tester, 'selection-category');

      expect(
        find.textContaining('Pick only expenses, or only income'),
        findsOneWidget,
      );
    });
  });

  group('changing the account of several', () {
    testWithDatabase('moves them and can be undone', (tester, db) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);
      await tester.tap(row(d.salary));
      await tester.pumpAndSettle();

      await tapKey(tester, 'selection-account');
      await tapKey(tester, 'choose-account-${d.basics.bkash}');

      final rows = {for (final t in await savedRows(db)) t.id: t};
      expect(rows[d.lunch]!.accountId, d.basics.bkash);
      expect(rows[d.salary]!.accountId, d.basics.bkash);
      expect(find.text('2 transactions moved to bKash'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final undone = {for (final t in await savedRows(db)) t.id: t};
      expect(undone[d.lunch]!.accountId, d.basics.cash);
    });

    testWithDatabase('a transfer in the picks is explained, not moved', (
      tester,
      db,
    ) async {
      final d = await openMonth(tester, db);
      await startSelecting(tester, d.lunch);
      await tester.tap(row(d.transfer));
      await tester.pumpAndSettle();

      await tapKey(tester, 'selection-account');

      expect(
        find.textContaining('Pick only expenses and income'),
        findsOneWidget,
      );
      final rows = {for (final t in await savedRows(db)) t.id: t};
      expect(rows[d.lunch]!.accountId, d.basics.cash);
    });
  });
}
