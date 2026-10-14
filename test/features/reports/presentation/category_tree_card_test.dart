import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/reports/domain/category_branch.dart';
import 'package:hishab/features/reports/presentation/widgets/category_tree_card.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';
import 'reports_screen_test.dart' show openReports;

Category cat(
  int id,
  String name, {
  int? parentId,
  int order = 0,
  CategoryType type = CategoryType.expense,
}) => Category(
  id: id,
  name: name,
  type: type,
  parentId: parentId,
  icon: 'restaurant',
  color: 0xFFEF5350,
  isArchived: false,
  sortOrder: order,
);

// Food(1) > Kacha bazar(2) > Fish(3); Rent(6); Salary(7, income).
final categories = [
  cat(1, 'Food'),
  cat(2, 'Kacha bazar', parentId: 1),
  cat(3, 'Fish', parentId: 2),
  cat(6, 'Rent', order: 1),
  cat(7, 'Salary', type: CategoryType.income),
];

List<CategoryBranch> spent() =>
    buildBranches(categories, {1: 1000, 3: 24000, 6: 40000});

List<CategoryBranch> earned() => buildBranches(categories, {7: 90000});

Future<void> pump(
  WidgetTester tester, {
  List<CategoryBranch>? expense,
  List<CategoryBranch>? income,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CategoryTreeCard(
          expense: expense ?? spent(),
          income: income ?? earned(),
        ),
      ),
    ),
  ),
);

String text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Finder row(int id, {bool own = false}) =>
    find.byKey(ValueKey('tree-row-$id${own ? '-own' : ''}'));

void main() {
  group('the card', () {
    testWidgets('lists the top level, biggest first, with rolled-up totals', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Where the money went'), findsOneWidget);
      expect(text(tester, 'tree-amount-6'), '৳400.00');
      expect(text(tester, 'tree-amount-1'), '৳250.00');
      expect(
        tester.getTopLeft(row(6)).dy,
        lessThan(tester.getTopLeft(row(1)).dy),
      );
    });

    testWidgets('shows each share of the whole', (tester) async {
      await pump(tester);

      // 40000 and 25000 of 65000.
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
    });

    testWidgets('keeps what is inside a group hidden until it is opened', (
      tester,
    ) async {
      await pump(tester);

      expect(row(2), findsNothing);
      expect(row(3), findsNothing);
      expect(find.byKey(const ValueKey('tree-toggle-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('tree-toggle-6')), findsNothing);
    });

    testWidgets('opens a group with a tap, down as far as it goes', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(row(1));
      await tester.pump();
      expect(row(2), findsOneWidget);
      expect(row(3), findsNothing);
      expect(text(tester, 'tree-amount-2'), '৳240.00');

      await tester.tap(row(2));
      await tester.pump();
      expect(row(3), findsOneWidget);
      expect(text(tester, 'tree-amount-3'), '৳240.00');
    });

    testWidgets('shows the money put directly on a group, inside it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(row(1));
      await tester.pump();

      expect(row(1, own: true), findsOneWidget);
      expect(find.text('Directly in Food'), findsOneWidget);
      expect(text(tester, 'tree-amount-1-own'), '৳10.00');
      // A group with nothing of its own has no such row.
      await tester.tap(row(2));
      await tester.pump();
      expect(row(2, own: true), findsNothing);
    });

    testWidgets('closes a group again', (tester) async {
      await pump(tester);
      await tester.tap(row(1));
      await tester.pump();
      await tester.tap(row(1));
      await tester.pump();

      expect(row(2), findsNothing);
    });

    testWidgets('opens and closes everything at once', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('tree-open-all')));
      await tester.pump();
      expect(row(3), findsOneWidget);
      expect(find.text('Close all'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tree-open-all')));
      await tester.pump();
      expect(row(2), findsNothing);
      expect(find.text('Open all'), findsOneWidget);
    });

    testWidgets('switches to income and back', (tester) async {
      await pump(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('tree-type')),
          matching: find.text('Income'),
        ),
      );
      await tester.pump();
      expect(find.text('Where the money came from'), findsOneWidget);
      expect(text(tester, 'tree-amount-7'), '৳900.00');
      expect(row(6), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('tree-type')),
          matching: find.text('Expense'),
        ),
      );
      await tester.pump();
      expect(row(6), findsOneWidget);
    });

    testWidgets('says so when there is nothing, and has no open-all button', (
      tester,
    ) async {
      await pump(tester, expense: const []);

      expect(find.byKey(const ValueKey('tree-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('tree-open-all')), findsNothing);
    });

    testWidgets('does not break on a small phone with a long amount', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        expense: buildBranches(categories, {3: 123456789012, 6: 5}),
      );
      await tester.tap(find.byKey(const ValueKey('tree-open-all')));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('on Reports', () {
    testWithDatabase('shows where the October money went', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final bazar = await insertTestCategory(
        db,
        name: 'Kacha bazar',
        parentId: b.food,
      );
      final fish = await insertTestCategory(db, name: 'Fish', parentId: bazar);
      for (final (category, amount) in [(fish, 30000), (b.food, 5000)]) {
        await db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amount: amount,
            accountId: b.cash,
            categoryId: Value(category),
            date: DateTime(2026, 10, 5),
          ),
        );
      }
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('category-tree-card')),
        300,
      );
      expect(text(tester, 'tree-amount-${b.food}'), '৳350.00');
      await tester.tap(find.byKey(ValueKey('tree-row-${b.food}')));
      await tester.pumpAndSettle();
      expect(text(tester, 'tree-amount-$bazar'), '৳300.00');
    });
  });
}
