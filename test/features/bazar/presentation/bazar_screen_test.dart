import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/bazar/data/bazar_repository.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> openBazar(WidgetTester tester) =>
    openFromMore(tester, 'Bazar list');

Future<int> addItem(
  AppDatabase db,
  String name, {
  int quantity = 1,
  int? price,
  bool done = false,
}) async {
  final repo = BazarRepository(db);
  final id = await repo.addItem(name, quantity: quantity, price: price);
  if (done) await repo.setDone(id, done: true);
  return id;
}

void main() {
  group('the list', () {
    testWithDatabase('invites you to add the first item', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      expect(find.text('Your list is empty'), findsOneWidget);
    });

    testWithDatabase('adds what is typed', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await enter(tester, 'bazar-name', 'Rice');
      await tapKey(tester, 'bazar-add');

      expect((await db.bazarDao.getAllItems()).single.name, 'Rice');
      expect(find.text('Rice'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bazar-name')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWithDatabase('says when the name is missing', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'bazar-add');

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(await db.bazarDao.getAllItems(), isEmpty);
    });

    testWithDatabase('shows the price and the line total', (tester, db) async {
      useTallScreen(tester);
      final rice = await addItem(db, 'Rice', quantity: 5, price: 12000);
      final salt = await addItem(db, 'Salt');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      expect(textOf(tester, 'item-sub-$rice'), '5 × ৳120.00');
      expect(textOf(tester, 'item-total-$rice'), '৳600.00');
      expect(textOf(tester, 'item-sub-$salt'), 'No price yet');
      expect(find.byKey(ValueKey('item-total-$salt')), findsNothing);
      expect(textOf(tester, 'bazar-estimated'), 'Estimated ৳600.00');
      expect(textOf(tester, 'bazar-no-price'), '1 item has no price');
    });

    testWithDatabase('edits an item and remembers its price', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await addItem(db, 'Rice');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tester.tap(find.text('Rice'));
      await tester.pumpAndSettle();
      await enter(tester, 'item-quantity', '3');
      await enter(tester, 'item-price', '130');
      await tapKey(tester, 'item-save');

      final item = (await db.bazarDao.getAllItems()).single;
      expect(item.id, id);
      expect(item.quantity, 3);
      expect(item.price, 13000);
      expect((await db.bazarDao.getAllPrices()).single.price, 13000);
    });

    testWithDatabase('swipes an item away', (tester, db) async {
      useTallScreen(tester);
      final id = await addItem(db, 'Rice');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tester.drag(
        find.byKey(ValueKey('dismiss-$id')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(await db.bazarDao.getAllItems(), isEmpty);
    });
  });

  group('changing the list', () {
    testWithDatabase('adds an item with how many and the price', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await enter(tester, 'bazar-name', 'Egg');
      await tapKey(tester, 'bazar-add-details');
      // The form starts with what was typed.
      expect(find.text('Add an item'), findsWidgets);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('item-name')))
            .controller!
            .text,
        'Egg',
      );
      await enter(tester, 'item-quantity', '12');
      await enter(tester, 'item-price', '15');
      await tapKey(tester, 'item-save');

      final item = (await db.bazarDao.getAllItems()).single;
      expect(item.name, 'Egg');
      expect(item.quantity, 12);
      expect(item.price, 1500);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bazar-name')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWithDatabase('adding with details can be cancelled', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'bazar-add-details');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await db.bazarDao.getAllItems(), isEmpty);
    });

    testWithDatabase('every row has a menu to edit it', (tester, db) async {
      useTallScreen(tester);
      final id = await addItem(db, 'Rice');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'item-menu-$id');
      await tapKey(tester, 'item-edit-$id');
      await enter(tester, 'item-name', 'Miniket rice');
      await tapKey(tester, 'item-save');

      expect((await db.bazarDao.getAllItems()).single.name, 'Miniket rice');
    });

    testWithDatabase('every row has a menu to delete it, with undo', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await addItem(db, 'Rice', quantity: 2, price: 12000);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'item-menu-$id');
      await tapKey(tester, 'item-delete-$id');
      expect(await db.bazarDao.getAllItems(), isEmpty);
      expect(find.text('Removed Rice'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final item = (await db.bazarDao.getAllItems()).single;
      expect(item.name, 'Rice');
      expect(item.quantity, 2);
      expect(item.price, 12000);
    });

    testWithDatabase('swiping an item away can be undone too', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await addItem(db, 'Rice');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tester.drag(
        find.byKey(ValueKey('dismiss-$id')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Removed Rice'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect((await db.bazarDao.getAllItems()).single.name, 'Rice');
    });

    testWithDatabase('removes the bought items after asking', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addItem(db, 'Rice', done: true);
      await addItem(db, 'Oil');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'bazar-menu');
      await tapKey(tester, 'bazar-menu-bought');
      expect(find.text('Remove the bought items?'), findsOneWidget);
      await tapKey(tester, 'bazar-confirm');

      expect(
        [for (final i in await db.bazarDao.getAllItems()) i.name],
        ['Oil'],
      );
      // No expense was made.
      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        isEmpty,
      );
    });

    testWithDatabase('has nothing to remove when nothing is ticked', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addItem(db, 'Oil');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'bazar-menu');

      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.byKey(const ValueKey('bazar-menu-bought')),
            )
            .enabled,
        isFalse,
      );
    });

    testWithDatabase('clears the whole list after asking', (tester, db) async {
      useTallScreen(tester);
      await addItem(db, 'Rice');
      await addItem(db, 'Oil', done: true);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'bazar-menu');
      await tapKey(tester, 'bazar-menu-clear');
      expect(find.text('All 2 items will be removed.'), findsOneWidget);
      await tapKey(tester, 'bazar-confirm');

      expect(await db.bazarDao.getAllItems(), isEmpty);
      expect(find.text('Your list is empty'), findsOneWidget);
    });

    testWithDatabase('keeps the list when clearing is cancelled', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addItem(db, 'Rice');
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'bazar-menu');
      await tapKey(tester, 'bazar-menu-clear');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await db.bazarDao.getAllItems(), hasLength(1));
    });

    testWithDatabase('the menu opens the remembered prices', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'bazar-menu');
      await tapKey(tester, 'bazar-menu-prices');

      expect(find.text('Remembered prices'), findsOneWidget);
      expect(find.text('No remembered prices yet'), findsOneWidget);
    });
  });

  group('remembered prices', () {
    testWithDatabase('are offered as chips that add the item with its price', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final repo = BazarRepository(db);
      final id = await repo.addItem('Rice');
      await repo.updateItem(id, name: 'Rice', quantity: 1, price: 12000);
      await repo.deleteItem(id);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      expect(find.text('Rice · ৳120.00'), findsOneWidget);
      await tapKey(tester, 'suggest-rice');

      final item = (await db.bazarDao.getAllItems()).single;
      expect(item.name, 'Rice');
      expect(item.price, 12000);
    });

    testWithDatabase('narrow down as you type', (tester, db) async {
      useTallScreen(tester);
      final repo = BazarRepository(db);
      for (final entry in {'Rice': 12000, 'Oil': 17000}.entries) {
        final id = await repo.addItem(entry.key);
        await repo.updateItem(
          id,
          name: entry.key,
          quantity: 1,
          price: entry.value,
        );
        await repo.deleteItem(id);
      }
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);
      expect(find.byKey(const ValueKey('suggest-rice')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggest-oil')), findsOneWidget);

      await enter(tester, 'bazar-name', 'oi');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('suggest-rice')), findsNothing);
      expect(find.byKey(const ValueKey('suggest-oil')), findsOneWidget);
    });
  });

  group('done shopping', () {
    testWithDatabase('is off until something is ticked', (tester, db) async {
      useTallScreen(tester);
      await addItem(db, 'Rice', price: 12000);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      expect(textOf(tester, 'bazar-ticked'), 'Tick what you bought');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('bazar-checkout')))
            .onPressed,
        isNull,
      );
    });

    testWithDatabase('adds up what is ticked', (tester, db) async {
      useTallScreen(tester);
      final rice = await addItem(db, 'Rice', quantity: 2, price: 12000);
      await addItem(db, 'Oil', price: 17000);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      await tapKey(tester, 'item-check-$rice');

      expect(textOf(tester, 'bazar-ticked'), '1 ticked · ৳240.00');
    });

    testWithDatabase('opens the add form with the total, and tidies up', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final rice = await addItem(db, 'Rice', quantity: 2, price: 12000);
      final egg = await addItem(db, 'Egg', price: 1500);
      await addItem(db, 'Oil', price: 17000);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);
      await tapKey(tester, 'item-check-$rice');
      await tapKey(tester, 'item-check-$egg');

      await tapKey(tester, 'bazar-checkout');

      expect(amountText(tester), '255');
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Note'))
            .controller!
            .text,
        'Bazar: Rice, Egg',
      );
      await chooseCategory(tester, b.food);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await db.transactionsDao.getAll()).single;
      expect(saved.amount, 25500);
      expect(saved.note, 'Bazar: Rice, Egg');
      // Only what was not bought is left, and the prices are remembered.
      expect(
        [for (final i in await db.bazarDao.getAllItems()) i.name],
        ['Oil'],
      );
      expect(await db.bazarDao.getAllPrices(), hasLength(2));
    });

    testWithDatabase('keeps the list when the form is left unsaved', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      final rice = await addItem(db, 'Rice', price: 12000);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);
      await tapKey(tester, 'item-check-$rice');
      await tapKey(tester, 'bazar-checkout');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(await db.bazarDao.getAllItems(), hasLength(1));
      expect(await db.transactionsDao.getAll(), isEmpty);
    });
  });
}
