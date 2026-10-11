import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

import '../../../helpers/pump_app.dart';

Future<CategoryRow> categoryNamed(AppDatabase db, String name) async {
  final all = await db.categoriesDao.getAll(includeArchived: true);
  return all.firstWhere((c) => c.name == name);
}

Future<void> openAddForm(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWithDatabase(
    'lists default categories with sub-categories, and switches to income',
    (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      expect(listRow('Food'), findsOneWidget);
      expect(listRow('Groceries'), findsOneWidget);
      expect(listRow('Restaurants'), findsOneWidget);
      expect(listRow('Rent'), findsOneWidget);
      expect(listRow('Salary'), findsNothing);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(listRow('Salary'), findsOneWidget);
      expect(listRow('Food'), findsNothing);
    },
    seedDefaults: true,
  );

  testWithDatabase('shows an empty state with a way to add a category', (
    tester,
    db,
  ) async {
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');

    expect(find.text('No expense categories'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add category'));
    await tester.pumpAndSettle();

    expect(find.text('New category'), findsOneWidget);
  });

  group('adding a category', () {
    testWithDatabase('saves the chosen name, icon and color', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        ' Pets ',
      );
      await tester.tap(find.byKey(const ValueKey('icon-pets')));
      await tester.tap(find.byKey(const ValueKey('color-ff42a5f5')));
      await tester.pump();
      await tapSave(tester, 'Add category');

      expect(find.text('New category'), findsNothing);
      expect(listRow('Pets'), findsOneWidget);
      final pets = await categoryNamed(db, 'Pets');
      expect(pets.type, CategoryType.expense);
      expect(pets.parentId, isNull);
      expect(pets.icon, 'pets');
      expect(pets.color, 0xFF42A5F5);
    });

    testWithDatabase('starts with the type of the tab it was opened from', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await openAddForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Rent income',
      );
      await tapSave(tester, 'Add category');

      expect(
        (await categoryNamed(db, 'Rent income')).type,
        CategoryType.income,
      );
      expect(listRow('Rent income'), findsOneWidget);
    });

    testWithDatabase('asks for a name', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);

      await tapSave(tester, 'Add category');

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('New category'), findsOneWidget);
    });

    testWithDatabase('shows the repository error for a duplicate name', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'food',
      );
      await tapSave(tester, 'Add category');

      expect(
        find.text('A category named "Food" already exists here.'),
        findsOneWidget,
      );
      expect(find.text('New category'), findsOneWidget);
    }, seedDefaults: true);

    testWithDatabase('adds a sub-category from the menu, parent preselected', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await openRowMenu(tester, 'Food');
      await tester.tap(find.text('Add sub-category'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DropdownButtonFormField<int?>),
          matching: find.text('Food'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Tiffin',
      );
      await tapSave(tester, 'Add category');

      expect(listRow('Tiffin'), findsOneWidget);
      final food = await categoryNamed(db, 'Food');
      expect((await categoryNamed(db, 'Tiffin')).parentId, food.id);
    }, seedDefaults: true);
  });

  group('editing a category', () {
    testWithDatabase('renames it and cannot change its type', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await tester.tap(listRow('Rent'));
      await tester.pumpAndSettle();

      expect(find.text('Edit category'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Name'))
            .controller!
            .text,
        'Rent',
      );
      expect(
        tester
            .widget<SegmentedButton<CategoryType>>(
              find.byType(SegmentedButton<CategoryType>),
            )
            .onSelectionChanged,
        isNull,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'House rent',
      );
      await tapSave(tester, 'Save changes');

      expect(listRow('House rent'), findsOneWidget);
      expect(listRow('Rent'), findsNothing);
    }, seedDefaults: true);

    testWithDatabase('a category with sub-categories stays top-level', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await tester.tap(listRow('Food'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<int?>>(
              find.byType(DropdownButtonFormField<int?>),
            )
            .onChanged,
        isNull,
      );
      expect(
        find.text('This category has sub-categories, so it stays top-level.'),
        findsOneWidget,
      );
    }, seedDefaults: true);

    testWithDatabase('moves a sub-category to the top level', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await tester.tap(listRow('Groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None (top-level)').last);
      await tester.pumpAndSettle();
      await tapSave(tester, 'Save changes');

      expect((await categoryNamed(db, 'Groceries')).parentId, isNull);
    }, seedDefaults: true);
  });

  group('archiving', () {
    testWithDatabase(
      'archives a category with its sub-categories, then restores them',
      (tester, db) async {
        useTallScreen(tester);
        await pumpAppWithDatabase(tester, db);
        await openFromMore(tester, 'Categories');

        await openRowMenu(tester, 'Food');
        await tester.tap(find.text('Archive'));
        await tester.pumpAndSettle();
        expect(find.text('Archive "Food"?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
        await tester.pumpAndSettle();

        expect(listRow('Food'), findsNothing);
        expect(listRow('Groceries'), findsNothing);
        expect(listRow('Rent'), findsOneWidget);
        expect(find.text('Food archived'), findsOneWidget);

        await tester.tap(find.byTooltip('Show archived'));
        await tester.pumpAndSettle();
        expect(listRow('Food'), findsOneWidget);
        expect(listRow('Groceries'), findsOneWidget);

        await openRowMenu(tester, 'Food');
        await tester.tap(find.text('Restore'));
        await tester.pumpAndSettle();

        expect(find.text('Archived'), findsNothing);
        expect(listRow('Groceries'), findsOneWidget);
      },
      seedDefaults: true,
    );

    testWithDatabase('undo brings an archived category back', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await openRowMenu(tester, 'Rent');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(listRow('Rent'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(listRow('Rent'), findsOneWidget);
    }, seedDefaults: true);

    testWithDatabase('explains why a sub-category cannot be restored alone', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final food = await categoryNamed(db, 'Food');
      await CategoriesRepository(db).archiveCategory(food.id);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await tester.tap(find.byTooltip('Show archived'));
      await tester.pumpAndSettle();

      await openRowMenu(tester, 'Groceries');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Restore "Food" first'), findsOneWidget);
      expect((await categoryNamed(db, 'Groceries')).isArchived, isTrue);
    }, seedDefaults: true);
  });
}
