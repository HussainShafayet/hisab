import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/bazar/data/bazar_repository.dart';

import '../../../helpers/pump_app.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

/// Opens Bazar list > menu > Remembered prices.
Future<void> openPrices(WidgetTester tester) async {
  await openFromMore(tester, 'Bazar list');
  await tapKey(tester, 'bazar-menu');
  await tapKey(tester, 'bazar-menu-prices');
}

Future<List<String>> saved(AppDatabase db) async => [
  for (final p in await db.bazarDao.getAllPrices()) '${p.name} ${p.price}',
];

void main() {
  testWithDatabase('says when nothing is remembered yet', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    expect(find.text('No remembered prices yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('price-add')), findsOneWidget);
  });

  testWithDatabase('lists the prices with the amount', (tester, db) async {
    useTallScreen(tester);
    final repo = BazarRepository(db);
    await repo.savePrice(name: 'Rice', price: 12000);
    await repo.savePrice(name: 'Oil', price: 18050);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('৳120.00'), findsOneWidget);
    expect(find.text('Oil'), findsOneWidget);
    expect(find.text('৳180.50'), findsOneWidget);
  });

  testWithDatabase('adds a price by hand', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    await tapKey(tester, 'price-add');
    await enter(tester, 'price-name', 'Egg');
    await enter(tester, 'price-amount', '15');
    await tapKey(tester, 'price-save');

    expect(await saved(db), ['Egg 1500']);
    expect(find.text('Egg'), findsOneWidget);
  });

  testWithDatabase('asks for a name and a price', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    await tapKey(tester, 'price-add');
    await tapKey(tester, 'price-save');

    expect(find.text('Enter a name.'), findsOneWidget);
    expect(await saved(db), isEmpty);
  });

  testWithDatabase('changes a price and its name', (tester, db) async {
    useTallScreen(tester);
    await BazarRepository(db).savePrice(name: 'Rice', price: 12000);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    expect(find.text('Edit price'), findsOneWidget);
    await enter(tester, 'price-name', 'Miniket rice');
    await enter(tester, 'price-amount', '135');
    await tapKey(tester, 'price-save');

    expect(await saved(db), ['Miniket rice 13500']);
  });

  testWithDatabase('says when the new name already has a price', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final repo = BazarRepository(db);
    await repo.savePrice(name: 'Rice', price: 12000);
    await repo.savePrice(name: 'Oil', price: 18000);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    await enter(tester, 'price-name', 'Oil');
    await tapKey(tester, 'price-save');

    expect(find.text('A price for Oil is already saved.'), findsOneWidget);
    expect(await saved(db), unorderedEquals(['Rice 12000', 'Oil 18000']));
  });

  testWithDatabase('removes a price from its menu, with undo', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await BazarRepository(db).savePrice(name: 'Rice', price: 12000);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    await tapKey(tester, 'price-menu-rice');
    await tapKey(tester, 'price-delete-rice');
    expect(await saved(db), isEmpty);
    expect(find.text('Removed the price of Rice'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(await saved(db), ['Rice 12000']);
  });

  testWithDatabase('removes a price by swiping it away', (tester, db) async {
    useTallScreen(tester);
    await BazarRepository(db).savePrice(name: 'Rice', price: 12000);
    await pumpAppWithDatabase(tester, db);
    await openPrices(tester);

    await tester.drag(
      find.byKey(const ValueKey('price-dismiss-rice')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(await saved(db), isEmpty);
  });

  testWithDatabase('a removed price is no longer offered on the list', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await BazarRepository(db).savePrice(name: 'Rice', price: 12000);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Bazar list');
    expect(find.byKey(const ValueKey('suggest-rice')), findsOneWidget);

    await tapKey(tester, 'bazar-menu');
    await tapKey(tester, 'bazar-menu-prices');
    await tapKey(tester, 'price-menu-rice');
    await tapKey(tester, 'price-delete-rice');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('suggest-rice')), findsNothing);
  });
}
