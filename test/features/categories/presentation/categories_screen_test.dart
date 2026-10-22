import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

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

// Food > Groceries > Rice, and Transport on its own.
Future<({int food, int groceries, int rice, int transport})> seedDeep(
  AppDatabase db,
) async {
  final food = await insertTestCategory(db, name: 'Food');
  final groceries = await insertTestCategory(
    db,
    name: 'Groceries',
    parentId: food,
  );
  final rice = await insertTestCategory(db, name: 'Rice', parentId: groceries);
  final transport = await insertTestCategory(db, name: 'Transport');
  return (food: food, groceries: groceries, rice: rice, transport: transport);
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
        tester.widget<Text>(find.byKey(const ValueKey('parent-value'))).data,
        'Food',
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

    testWithDatabase('a category with sub-categories can be moved too', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      final food = await categoryNamed(db, 'Food');

      await tester.tap(listRow('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();

      // The sheet opens, and Food itself is not among the places it can go.
      expect(find.byType(CategoryPickerSheet), findsOneWidget);
      expect(find.byKey(ValueKey('category-option-${food.id}')), findsNothing);
      expect(find.byKey(const ValueKey('category-top-level')), findsOneWidget);
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
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('parent-value'))).data,
        'Food',
      );
      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-top-level')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('parent-value'))).data,
        'Top level',
      );
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

        await tester.tap(find.byKey(const ValueKey('show-archived')));
        await tester.pumpAndSettle();
        expect(listRow('Food'), findsOneWidget);
        expect(listRow('Groceries'), findsOneWidget);
        expect(find.textContaining('Archived'), findsWidgets);

        await openRowMenu(tester, 'Food');
        await tester.tap(find.text('Restore'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Archived'), findsNothing);
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
      await tester.tap(find.byKey(const ValueKey('show-archived')));
      await tester.pumpAndSettle();

      await openRowMenu(tester, 'Groceries');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Restore "Food" first'), findsOneWidget);
      expect((await categoryNamed(db, 'Groceries')).isArchived, isTrue);
    }, seedDefaults: true);
  });

  group('categories inside categories', () {
    testWithDatabase('are listed one level deeper each time', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      double left(String name) => tester.getTopLeft(find.text(name)).dx;
      expect(listRow('Rice'), findsOneWidget);
      expect(left('Groceries'), greaterThan(left('Food')));
      expect(left('Rice'), greaterThan(left('Groceries')));
      expect(left('Transport'), left('Food'));
    });

    testWithDatabase('say how many sub-categories they hold', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final ids = await seedDeep(db);
      await insertTestCategory(db, name: 'Snacks', parentId: ids.food);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      expect(
        find.descendant(
          of: listRow('Food'),
          matching: find.text('2 sub-categories'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: listRow('Groceries'),
          matching: find.text('1 sub-category'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: listRow('Rice'),
          matching: find.textContaining('sub-categor'),
        ),
        findsNothing,
      );
    });

    testWithDatabase('open and close with their arrow', (tester, db) async {
      useTallScreen(tester);
      final ids = await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      expect(listRow('Groceries'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('category-toggle-${ids.food}')));
      await tester.pumpAndSettle();

      // Closing Food hides everything inside it, however deep.
      expect(listRow('Food'), findsOneWidget);
      expect(listRow('Groceries'), findsNothing);
      expect(listRow('Rice'), findsNothing);

      await tester.tap(find.byKey(ValueKey('category-toggle-${ids.food}')));
      await tester.pumpAndSettle();

      expect(listRow('Groceries'), findsOneWidget);
      expect(listRow('Rice'), findsOneWidget);
    });

    testWithDatabase('a category with nothing inside has no arrow', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final ids = await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      expect(
        find.byKey(ValueKey('category-toggle-${ids.transport}')),
        findsNothing,
      );
      expect(find.byKey(ValueKey('category-toggle-${ids.rice}')), findsNothing);
    });

    testWithDatabase('can all be closed and opened with one button', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await tester.tap(find.byKey(const ValueKey('collapse-all')));
      await tester.pumpAndSettle();
      expect(listRow('Food'), findsOneWidget);
      expect(listRow('Groceries'), findsNothing);
      expect(find.byTooltip('Open all'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('collapse-all')));
      await tester.pumpAndSettle();
      expect(listRow('Rice'), findsOneWidget);
      expect(find.byTooltip('Close all'), findsOneWidget);
    });

    testWithDatabase('have no open/close all button when nothing is nested', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestCategory(db, name: 'Food');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      expect(find.byKey(const ValueKey('collapse-all')), findsNothing);
    });

    testWithDatabase('offer "Add sub-category" down to the fifth level', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      var parent = await insertTestCategory(db, name: 'L1');
      for (final name in ['L2', 'L3', 'L4', 'L5']) {
        parent = await insertTestCategory(db, name: name, parentId: parent);
      }
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await openRowMenu(tester, 'L4');
      expect(find.text('Add sub-category'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await openRowMenu(tester, 'L5');
      expect(find.text('Add sub-category'), findsNothing);
    });

    testWithDatabase(
      'the places a category can go leave out itself and what is inside it',
      (tester, db) async {
        useTallScreen(tester);
        final ids = await seedDeep(db);
        await pumpAppWithDatabase(tester, db);
        await openFromMore(tester, 'Categories');

        await tester.tap(listRow('Groceries'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('parent-field')));
        await tester.pumpAndSettle();

        expect(find.byKey(ValueKey('category-option-${ids.food}')), findsOne);
        expect(
          find.byKey(ValueKey('category-option-${ids.transport}')),
          findsOne,
        );
        // Groceries itself and Rice (inside it) are not offered.
        expect(
          find.byKey(ValueKey('category-option-${ids.groceries}')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('category-option-${ids.rice}')),
          findsNothing,
        );
        // The place it is in now is marked.
        expect(
          find.descendant(
            of: find.byKey(ValueKey('category-option-${ids.food}')),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOneWidget,
        );
      },
    );

    testWithDatabase('a category can be moved inside a sub-category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final ids = await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await tester.tap(listRow('Transport'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('category-expand-${ids.food}')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('category-option-${ids.groceries}')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('parent-value'))).data,
        'Food › Groceries',
      );
      await tapSave(tester, 'Save changes');

      expect((await categoryNamed(db, 'Transport')).parentId, ids.groceries);
    });

    testWithDatabase('a category with others inside can be moved with them', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final ids = await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await tester.tap(listRow('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('category-option-${ids.transport}')),
      );
      await tester.pumpAndSettle();
      await tapSave(tester, 'Save changes');

      expect((await categoryNamed(db, 'Food')).parentId, ids.transport);
      // What was inside Food came along.
      expect((await categoryNamed(db, 'Groceries')).parentId, ids.food);
    });
  });

  group('the category form', () {
    testWithDatabase('shows a preview of the category as it is filled in', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);

      String previewName() =>
          tester.widget<Text>(find.byKey(const ValueKey('preview-name'))).data!;
      expect(previewName(), 'Category name');
      expect(find.text('Expense · top level'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Pets',
      );
      await tester.pump();
      expect(previewName(), 'Pets');

      await tester.tap(find.text('Income'));
      await tester.pump();
      expect(find.text('Income · top level'), findsOneWidget);
    });

    testWithDatabase('says where it goes in the preview', (tester, db) async {
      useTallScreen(tester);
      await insertTestCategory(db, name: 'Food');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.text('Inside Food'), findsOneWidget);
    });

    testWithDatabase('switching the type forgets the place it was put', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestCategory(db, name: 'Food');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);
      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Income'));
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('parent-value'))).data,
        'Top level',
      );
    });

    testWithDatabase('the "Inside" sheet has no way to add a category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('category-add')), findsNothing);
      expect(find.byKey(const ValueKey('category-top-level')), findsOneWidget);
      expect(
        find.text('There is no other category to put it inside yet.'),
        findsOneWidget,
      );
    });

    testWithDatabase('the "Inside" sheet can search', (tester, db) async {
      useTallScreen(tester);
      final ids = await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('parent-field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-search')),
        'rice',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('category-option-${ids.rice}')), findsOne);
      expect(find.byKey(const ValueKey('category-top-level')), findsNothing);
    });
  });

  group('merging', () {
    Future<void> chooseTarget(WidgetTester tester, String name) async {
      await tester.tap(
        find
            .descendant(
              of: find.byType(CategoryPickerSheet),
              matching: find.text(name),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWithDatabase('folds a category into another and says so', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final rickshaw = await insertTestCategory(db, name: 'Rickshaw');
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 4000,
        accountId: b.cash,
        categoryId: rickshaw,
        date: DateTime(2026, 10, 5, 12),
      );
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await openRowMenu(tester, 'Rickshaw');
      await tester.tap(find.text('Merge into…'));
      await tester.pumpAndSettle();
      expect(find.text('Merge "Rickshaw" into'), findsOneWidget);
      await chooseTarget(tester, 'Transport');
      expect(find.text('Merge "Rickshaw" into "Transport"?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-merge')));
      await tester.pumpAndSettle();

      expect(listRow('Rickshaw'), findsNothing);
      expect(find.text('1 transaction moved to Transport'), findsOneWidget);
      expect(
        (await db.transactionsDao.getAll()).single.categoryId,
        b.transport,
      );
      expect((await categoryNamed(db, 'Rickshaw')).isArchived, isTrue);
    });

    testWithDatabase(
      'the list of places leaves out itself and the other type',
      (tester, db) async {
        useTallScreen(tester);
        await seedBasics(db);
        await insertTestCategory(db, name: 'Rickshaw');
        await pumpAppWithDatabase(tester, db);
        await openFromMore(tester, 'Categories');

        await openRowMenu(tester, 'Rickshaw');
        await tester.tap(find.text('Merge into…'));
        await tester.pumpAndSettle();

        Finder inSheet(String name) => find.descendant(
          of: find.byType(CategoryPickerSheet),
          matching: find.text(name),
        );
        expect(inSheet('Transport'), findsWidgets);
        expect(inSheet('Rickshaw'), findsNothing);
        // Salary is income.
        expect(inSheet('Salary'), findsNothing);
      },
    );

    testWithDatabase('Cancel keeps everything', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await insertTestCategory(db, name: 'Rickshaw');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await openRowMenu(tester, 'Rickshaw');
      await tester.tap(find.text('Merge into…'));
      await tester.pumpAndSettle();
      await chooseTarget(tester, 'Transport');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(listRow('Rickshaw'), findsOneWidget);
      expect((await categoryNamed(db, 'Rickshaw')).isArchived, isFalse);
    });

    testWithDatabase('a category with sub-categories is explained', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedDeep(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      await openRowMenu(tester, 'Food');
      await tester.tap(find.text('Merge into…'));
      await tester.pumpAndSettle();

      expect(
        find.text('"Food" has sub-categories. Move or merge them first.'),
        findsOneWidget,
      );
      expect(find.byType(CategoryPickerSheet), findsNothing);
    });

    testWithDatabase('an archived category has no merge', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      final old = await insertTestCategory(db, name: 'Old');
      await db.categoriesDao.setArchived(old, archived: true);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await tester.tap(find.byKey(const ValueKey('show-archived')));
      await tester.pumpAndSettle();

      await openRowMenu(tester, 'Old');

      expect(find.text('Merge into…'), findsNothing);
      expect(find.text('Restore'), findsOneWidget);
    });
  });
}
