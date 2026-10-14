import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/data/category_pack.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

const _tile = ValueKey('add-defaults');

void main() {
  testWithDatabase('offers the missing everyday categories', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await insertTestCategory(db, name: 'Food');
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');

    await tester.scrollUntilVisible(find.byKey(_tile), 300);
    expect(find.byKey(_tile), findsOneWidget);
    expect(find.text('Everyday Bangladesh categories'), findsOneWidget);
    final missing = missingDefaults([]).length - 1;
    expect(find.textContaining('$missing more are ready'), findsOneWidget);
  });

  testWithDatabase('adds them and then goes away', (tester, db) async {
    useTallScreen(tester);
    await insertTestCategory(db, name: 'Food');
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await tester.scrollUntilVisible(find.byKey(_tile), 300);

    await tester.tap(find.byKey(const ValueKey('add-defaults-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('categories added'), findsOneWidget);
    expect(find.byKey(_tile), findsNothing);
    // Sub-categories are there, inside their group.
    expect(await db.categoriesDao.getAll(), hasLength(greaterThan(60)));
  });

  testWithDatabase('is not shown when nothing is missing', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.byKey(_tile), findsNothing);
  }, seedDefaults: true);

  group('the big tree', () {
    testWithDatabase('opens the top level and closes the groups inside it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      // Food shows what is directly inside it, not what is inside those.
      expect(listRow('Food'), findsOneWidget);
      expect(listRow('Kacha bazar'), findsOneWidget);
      expect(listRow('Fish'), findsNothing);
    }, seedDefaults: true);

    testWithDatabase('a group opens with its arrow', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      final bazar = (await db.categoriesDao.getAll()).firstWhere(
        (c) => c.name == 'Kacha bazar',
      );

      await tester.tap(find.byKey(ValueKey('category-toggle-${bazar.id}')));
      await tester.pumpAndSettle();

      expect(listRow('Fish'), findsOneWidget);
      expect(listRow('Vegetables'), findsOneWidget);
    }, seedDefaults: true);

    testWithDatabase('a small tree starts fully open', (tester, db) async {
      useTallScreen(tester);
      final food = await insertTestCategory(db, name: 'Food');
      final bazar = await insertTestCategory(
        db,
        name: 'Kacha bazar',
        parentId: food,
      );
      await insertTestCategory(db, name: 'Fish', parentId: bazar);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      expect(listRow('Fish'), findsOneWidget);
    });
  });
}
