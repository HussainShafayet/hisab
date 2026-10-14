import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/investments/data/investments_repository.dart';
import 'package:hishab/features/investments/domain/investment.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> openInvestments(WidgetTester tester) =>
    openFromMore(tester, 'Investments');

/// A farm with 10,000 put in, 1,500 profit and 2,000 taken back.
Future<int> seedFarm(AppDatabase db, {int? account}) async {
  final repo = InvestmentsRepository(db);
  final id = await repo.createInvestment(
    name: 'Poultry farm',
    startedOn: DateTime(2026, 9, 1),
  );
  Future<void> add(InvestmentEntryKind kind, int amount) => repo.addEntry(
    id,
    kind: kind,
    amount: amount,
    date: DateTime(2026, 10, 1),
    accountId: account,
  );
  await add(InvestmentEntryKind.putIn, 1000000);
  await add(InvestmentEntryKind.profit, 150000);
  await add(InvestmentEntryKind.takeBack, 200000);
  return id;
}

Future<void> fill(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

void main() {
  group('the list', () {
    testWithDatabase('is reached from More and starts empty', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openInvestments(tester);

      expect(appBarTitle('Investments'), findsOneWidget);
      expect(find.text('No investments yet'), findsOneWidget);
    });

    testWithDatabase('shows the totals and each investment', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openInvestments(tester);

      // 15,000 profit received + 8,000 still in at cost + 2,000 back - 10,000.
      expect(textOf(tester, 'investments-return'), '+৳1,500.00');
      expect(textOf(tester, 'investments-roi'), '+15%');
      expect(textOf(tester, 'investments-put-in'), '৳10,000.00');
      expect(textOf(tester, 'investments-profit'), '৳1,500.00');
      expect(textOf(tester, 'investments-value'), '৳8,000.00');
      expect(find.text('Poultry farm'), findsOneWidget);
      expect(textOf(tester, 'investment-return-$id'), '+৳1,500.00');
      expect(textOf(tester, 'investment-roi-$id'), '+15%');
    });

    testWithDatabase('shows a loss in the same place', (tester, db) async {
      useTallScreen(tester);
      final id = await seedFarm(db);
      await InvestmentsRepository(db).setCurrentValue(id, 500000);
      await pumpAppWithDatabase(tester, db);
      await openInvestments(tester);

      // 1,500 + 2,000 + 5,000 - 10,000 = -1,500.
      expect(textOf(tester, 'investments-return'), '-৳1,500.00');
      expect(find.text('Loss so far'), findsOneWidget);
    });

    testWithDatabase('opens an investment', (tester, db) async {
      useTallScreen(tester);
      final id = await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openInvestments(tester);

      await tester.tap(find.byKey(ValueKey('investment-$id')));
      await tester.pumpAndSettle();

      expect(appBarTitle('Poultry farm'), findsOneWidget);
    });
  });

  group('making one', () {
    testWithDatabase('asks for a name, then opens it to add money', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openInvestments(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'New investment'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('investment-form-save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);

      await fill(tester, 'investment-name', 'Rahim\'s shop');
      await tapKey(tester, 'investment-form-save');

      expect(appBarTitle('Rahim\'s shop'), findsOneWidget);
      expect(find.byKey(const ValueKey('investment-no-lines')), findsOneWidget);
      final saved = await db.investmentsDao.getAllInvestments();
      expect(saved.single.name, 'Rahim\'s shop');
    });

    testWithDatabase('can be renamed from its menu', (tester, db) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openInvestments(tester);
      await tester.tap(find.text('Poultry farm'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('investment-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await fill(tester, 'investment-name', 'Fish farm');
      await tapKey(tester, 'investment-form-save');

      expect(appBarTitle('Fish farm'), findsOneWidget);
    });
  });

  group('the detail', () {
    Future<void> openFarm(WidgetTester tester) async {
      await openInvestments(tester);
      await tester.tap(find.text('Poultry farm'));
      await tester.pumpAndSettle();
    }

    testWithDatabase('shows how it is doing and every line', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      expect(textOf(tester, 'investment-return'), '+৳1,500.00');
      expect(textOf(tester, 'investment-roi'), '+15%');
      expect(textOf(tester, 'investment-put-in'), '৳10,000.00');
      expect(textOf(tester, 'investment-taken-back'), '৳2,000.00');
      expect(textOf(tester, 'investment-still-in'), '৳8,000.00');
      expect(textOf(tester, 'investment-profit'), '৳1,500.00');
      expect(textOf(tester, 'investment-value'), '৳8,000.00');
      expect(find.text('Worth now (at cost)'), findsOneWidget);
      expect(find.text('Put in'), findsWidgets);
      expect(find.text('Profit'), findsWidgets);
      expect(find.text('Taken back'), findsWidgets);
    });

    testWithDatabase('puts money in', (tester, db) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      await tapKey(tester, 'investment-add-put-in');
      await fill(tester, 'investment-amount', '5000');
      await tapKey(tester, 'investment-save');

      expect(textOf(tester, 'investment-put-in'), '৳15,000.00');
      expect(textOf(tester, 'investment-still-in'), '৳13,000.00');
    });

    testWithDatabase('records profit and moves an account', (tester, db) async {
      useTallScreen(tester);
      await seedFarm(db);
      final cash = await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      await tapKey(tester, 'investment-add-profit');
      await fill(tester, 'investment-amount', '300');
      await tester.tap(find.byKey(const ValueKey('investment-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'investment-save');

      expect(textOf(tester, 'investment-profit'), '৳1,800.00');
      final all = await db.transactionsDao.getAll();
      expect(all.single.accountId, cash);
      expect(all.single.amount, 30000);
      expect(all.single.isAdjustment, isFalse);
    });

    testWithDatabase('refuses to take back more than is still in', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      await tapKey(tester, 'investment-add-take-back');
      await fill(tester, 'investment-amount', '9000');
      await tapKey(tester, 'investment-save');

      expect(find.byKey(const ValueKey('investment-error')), findsOneWidget);
      expect(find.textContaining('record it as profit'), findsOneWidget);
      // The dialog stays, and nothing was saved.
      expect(find.byKey(const ValueKey('investment-save')), findsOneWidget);
      expect(textOf(tester, 'investment-taken-back'), '৳2,000.00');
    });

    testWithDatabase('asks for an amount above zero', (tester, db) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      await tapKey(tester, 'investment-add-put-in');
      await fill(tester, 'investment-amount', '0');
      await tapKey(tester, 'investment-save');

      expect(find.text('The amount must be above zero.'), findsOneWidget);
    });

    testWithDatabase('sets what it is worth now, and goes back to cost', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      await tapKey(tester, 'investment-set-value');
      await fill(tester, 'investment-value', '12000');
      await tapKey(tester, 'investment-value-save');
      expect(textOf(tester, 'investment-value'), '৳12,000.00');
      expect(find.text('Worth now'), findsOneWidget);
      // 1,500 + 2,000 + 12,000 - 10,000.
      expect(textOf(tester, 'investment-return'), '+৳5,500.00');

      await tapKey(tester, 'investment-set-value');
      await tapKey(tester, 'investment-value-clear');
      expect(textOf(tester, 'investment-value'), '৳8,000.00');
      expect(find.text('Worth now (at cost)'), findsOneWidget);
    });

    testWithDatabase(
      'deletes a line after asking, and takes the account back',
      (tester, db) async {
        useTallScreen(tester);
        final cash = await insertTestAccount(db, name: 'Cash');
        final id = await seedFarm(db, account: cash);
        await pumpAppWithDatabase(tester, db);
        await openFarm(tester);
        final first = (await db.investmentsDao.getEntries(id)).first;
        final transactions = (await db.transactionsDao.getAll()).length;

        await tapKey(tester, 'investment-entry-delete-${first.id}');
        expect(find.text('Remove this line?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('investment-confirm')));
        await tester.pumpAndSettle();

        expect(textOf(tester, 'investment-put-in'), '৳0.00');
        expect((await db.transactionsDao.getAll()).length, transactions - 1);
      },
    );

    testWithDatabase('closes, shows it, and opens again', (tester, db) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      await tester.tap(find.byKey(const ValueKey('investment-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('investment-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('investment-closed')), findsOneWidget);
      // Closed: what was not taken back (8,000) is lost.
      expect(textOf(tester, 'investment-return'), '-৳6,500.00');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('investment-add-put-in')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('investment-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('investment-closed')), findsNothing);
      expect(textOf(tester, 'investment-return'), '+৳1,500.00');
    });

    testWithDatabase('deletes the whole investment after asking', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);
      await openFarm(tester);

      await tester.tap(find.byKey(const ValueKey('investment-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('investment-confirm')));
      await tester.pumpAndSettle();

      expect(appBarTitle('Investments'), findsOneWidget);
      expect(await db.investmentsDao.getAllInvestments(), isEmpty);
    });

    testWithDatabase('cannot take money back when none is left', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await InvestmentsRepository(
        db,
      ).createInvestment(name: 'Poultry farm', startedOn: DateTime(2026, 9, 1));
      await pumpAppWithDatabase(tester, db);
      await openInvestments(tester);
      await tester.tap(find.text('Poultry farm'));
      await tester.pumpAndSettle();

      expect(id, isPositive);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('investment-add-take-back')),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('on Home', () {
    testWithDatabase('stays away with no investments', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('investments-home-card')), findsNothing);
    });

    testWithDatabase('shows what was put in and what it made', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedFarm(db);
      await pumpAppWithDatabase(tester, db);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('investments-home-card')),
        300,
      );
      expect(textOf(tester, 'home-investments-put-in'), '৳10,000.00');
      expect(find.text('+৳1,500.00  +15%'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('investments-home-card')));
      await tester.pumpAndSettle();
      expect(appBarTitle('Investments'), findsOneWidget);
    });
  });
}
