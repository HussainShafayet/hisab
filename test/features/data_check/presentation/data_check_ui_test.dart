import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

// Today is Sunday 11 October 2026.
Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> openCheck(WidgetTester tester, AppDatabase db) async {
  useTallScreen(tester);
  await pumpAppWithDatabase(tester, db);
  await openFromMore(tester, 'Data check');
}

Future<int> spend(
  AppDatabase db,
  Basics b, {
  int amount = 125000,
  DateTime? date,
  String note = 'Rent',
  int? category,
}) => addTransaction(
  db,
  type: TransactionType.expense,
  amount: amount,
  accountId: b.cash,
  categoryId: category ?? b.food,
  date: date ?? DateTime(2026, 10, 5, 12),
  note: note,
);

void main() {
  testWithDatabase('says all is well when there is nothing to look at', (
    tester,
    db,
  ) async {
    final b = await seedBasics(db);
    await spend(db, b);

    await openCheck(tester, db);

    expect(appBarTitle('Data check'), findsOneWidget);
    expect(find.text('Everything looks fine'), findsOneWidget);
  });

  testWithDatabase('an empty app is fine too', (tester, db) async {
    await openCheck(tester, db);

    expect(find.text('Everything looks fine'), findsOneWidget);
  });

  testWithDatabase(
    'lists an entry made twice and deletes the extra, with Undo',
    (tester, db) async {
      final b = await seedBasics(db);
      final first = await spend(db, b);
      final second = await spend(db, b);
      await openCheck(tester, db);

      expect(find.byKey(const ValueKey('check-duplicates')), findsOneWidget);
      expect(find.text('2 times, ৳1,250.00, 5 Oct 2026'), findsOneWidget);
      expect(
        find.text('1 thing to look at. Nothing is changed unless you say so.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ValueKey('delete-extra-$first')));
      await tester.pumpAndSettle();
      expect(find.text('Delete the extra one?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-delete-extra')));
      await tester.pumpAndSettle();

      final left = await db.transactionsDao.getAll();
      expect(left.map((t) => t.id), [first]);
      expect(find.text('1 transaction deleted'), findsOneWidget);
      expect(find.text('Everything looks fine'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect((await db.transactionsDao.getAll()).map((t) => t.id), [
        first,
        second,
      ]);
      expect(find.byKey(const ValueKey('check-duplicates')), findsOneWidget);
    },
  );

  testWithDatabase('Cancel keeps the copies', (tester, db) async {
    final b = await seedBasics(db);
    final first = await spend(db, b);
    await spend(db, b);
    await openCheck(tester, db);

    await tester.tap(find.byKey(ValueKey('delete-extra-$first')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await db.transactionsDao.getAll(), hasLength(2));
  });

  testWithDatabase('lists a date in the future', (tester, db) async {
    final b = await seedBasics(db);
    final id = await spend(db, b, date: DateTime(2027, 1, 3, 12), note: 'Typo');
    await openCheck(tester, db);

    expect(find.byKey(const ValueKey('check-future')), findsOneWidget);
    expect(find.byKey(ValueKey('check-item-$id')), findsOneWidget);
  });

  testWithDatabase('lists what is far above the usual', (tester, db) async {
    final b = await seedBasics(db);
    for (var i = 0; i < 9; i++) {
      await spend(
        db,
        b,
        amount: 10000,
        date: DateTime(2026, 9, 1 + i, 12),
        note: 'Lunch $i',
      );
    }
    final slip = await spend(db, b, amount: 4000000, note: 'Extra zero');
    await openCheck(tester, db);

    expect(find.byKey(const ValueKey('check-large')), findsOneWidget);
    expect(find.byKey(ValueKey('check-item-$slip')), findsOneWidget);
  });

  testWithDatabase('says how much sits in Other', (tester, db) async {
    final b = await seedBasics(db);
    final other = await insertTestCategory(db, name: 'Other');
    await spend(db, b, amount: 30000, category: other, note: 'Something');
    await spend(db, b, amount: 50000, category: other, note: 'Else');
    await openCheck(tester, db);

    expect(find.byKey(const ValueKey('check-other')), findsOneWidget);
    expect(find.textContaining('2 entries worth ৳800.00'), findsOneWidget);
  });

  testWithDatabase('a tap on an entry opens it to fix', (tester, db) async {
    final b = await seedBasics(db);
    final id = await spend(db, b, date: DateTime(2027, 1, 3, 12));
    await openCheck(tester, db);

    await tester.tap(find.byKey(ValueKey('check-item-$id')));
    await tester.pumpAndSettle();

    expect(appBarTitle('Edit transaction'), findsOneWidget);
  });

  testWithDatabase('shows categories that look alike, and opens Categories', (
    tester,
    db,
  ) async {
    await seedBasics(db);
    final a = await insertTestCategory(db, name: 'Utilities');
    final c = await insertTestCategory(db, name: 'Utility');
    await openCheck(tester, db);

    expect(find.byKey(const ValueKey('check-similar')), findsOneWidget);
    expect(find.byKey(ValueKey('check-pair-$a-$c')), findsOneWidget);
    expect(find.text('Utilities  ≈  Utility'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('check-pair-$a-$c')));
    await tester.pumpAndSettle();

    expect(appBarTitle('Categories'), findsOneWidget);
  });

  testWithDatabase('counts the things to look at, all together', (
    tester,
    db,
  ) async {
    final b = await seedBasics(db);
    await spend(db, b);
    await spend(db, b);
    await spend(db, b, date: DateTime(2027, 1, 3, 12), note: 'Later');
    await openCheck(tester, db);

    expect(
      find.text('2 things to look at. Nothing is changed unless you say so.'),
      findsOneWidget,
    );
  });

  testWithDatabase('is in More, under Setup', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('More'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data check'), findsOneWidget);
    expect(find.text('Duplicates, odd dates and amounts'), findsOneWidget);
  });
}
