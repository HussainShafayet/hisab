import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/tags/data/tags_repository.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// A tag called [name] with an expense of [amount] on 5 October.
Future<int> tagWithExpense(
  AppDatabase db,
  Basics b, {
  String name = 'Cox Bazar',
  int amount = 25000,
}) async {
  final tag = await TagsRepository(db).createTag(name);
  await TransactionsRepository(db).addTransaction(
    TransactionInput(
      type: TransactionType.expense,
      amount: amount,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 5),
      tagId: tag,
    ),
  );
  return tag;
}

void main() {
  group('the trips and events list', () {
    testWithDatabase('invites you to make the first one', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Trips & events');

      expect(find.text('No trips or events yet'), findsOneWidget);
    });

    testWithDatabase('makes a tag', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Trips & events');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('tag-name')), 'Eid');
      await tapKey(tester, 'tag-save');

      expect((await db.tagsDao.getAll()).single.name, 'Eid');
      expect(find.text('Eid'), findsOneWidget);
    });

    testWithDatabase('says a name is taken', (tester, db) async {
      useTallScreen(tester);
      await TagsRepository(db).createTag('Eid');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Trips & events');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('tag-name')), 'eid');
      await tapKey(tester, 'tag-save');

      expect(find.text('There is already a tag called "Eid".'), findsOneWidget);
      expect(await db.tagsDao.getAll(), hasLength(1));
    });

    testWithDatabase('shows what each one cost', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final tag = await tagWithExpense(db, b);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Trips & events');

      expect(textOf(tester, 'tag-spent-$tag'), '৳250.00');
      expect(find.text('1 transaction · 5 Oct 2026'), findsOneWidget);
    });
  });

  group('one trip or event', () {
    testWithDatabase('lists what was spent in it', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final tag = await tagWithExpense(db, b);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Trips & events');
      await tapKey(tester, 'tag-row-$tag');

      expect(appBarTitle('Cox Bazar'), findsOneWidget);
      expect(textOf(tester, 'tag-expense'), '৳250.00');
      expect(textOf(tester, 'tag-count'), '1 transaction · 5 Oct 2026');
      expect(find.text('Food'), findsOneWidget);
    });

    testWithDatabase('is renamed', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final tag = await tagWithExpense(db, b);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Trips & events');
      await tapKey(tester, 'tag-row-$tag');

      await tapKey(tester, 'tag-menu');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('tag-name')), 'Sylhet');
      await tapKey(tester, 'tag-save');

      expect(appBarTitle('Sylhet'), findsOneWidget);
    });

    testWithDatabase('is deleted, and its transactions stay', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final tag = await tagWithExpense(db, b);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Trips & events');
      await tapKey(tester, 'tag-row-$tag');

      await tapKey(tester, 'tag-menu');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'confirm-delete-tag');

      expect(await db.tagsDao.getAll(), isEmpty);
      final rows = await db.transactionsDao.getAll();
      expect(rows.single.tagId, isNull);
      expect(find.text('No trips or events yet'), findsOneWidget);
    });
  });

  group('the transaction form', () {
    testWithDatabase('saves the chosen tag with the expense', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final tag = await TagsRepository(db).createTag('Eid');
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '500');
      await chooseCategory(tester, b.food);
      await tapKey(tester, 'tag-$tag');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await db.transactionsDao.getAll()).single.tagId, tag);
    });

    testWithDatabase('makes a new tag on the spot', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '500');
      await chooseCategory(tester, b.food);
      await tapKey(tester, 'new-tag');
      await tester.enterText(find.byKey(const ValueKey('tag-name')), 'Tour');
      await tapKey(tester, 'tag-save');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final tag = (await db.tagsDao.getAll()).single;
      expect(tag.name, 'Tour');
      expect((await db.transactionsDao.getAll()).single.tagId, tag.id);
    });

    testWithDatabase('has no tag unless one is chosen', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await TagsRepository(db).createTag('Eid');
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '500');
      await chooseCategory(tester, b.food);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await db.transactionsDao.getAll()).single.tagId, isNull);
    });

    testWithDatabase('shows the tag on the saved transaction', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await tagWithExpense(db, b);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('#Cox Bazar'), findsOneWidget);
    });
  });
}
