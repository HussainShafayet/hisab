import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/fun/presentation/widgets/takka_card.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// "Now" in widget tests is Sunday 11 October 2026.
double top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  group('the order of Home', () {
    testWithDatabase('the total balance is above what needs doing', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      // Ten entries and no backup: the backup card shows.
      for (var i = 0; i < 10; i++) {
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 1000,
          accountId: b.cash,
          categoryId: b.food,
          date: DateTime(2026, 10, 1 + i, 12),
        );
      }
      await pumpAppWithDatabase(tester, db);

      expect(find.text('Time to back up'), findsOneWidget);
      expect(
        top(tester, find.text('Total balance')),
        lessThan(top(tester, find.text('Time to back up'))),
      );
    });

    testWithDatabase(
      'this month, plans and loans, top spending, in that order',
      (tester, db) async {
        useTallScreen(tester);
        await seedBasics(db);
        await pumpAppWithDatabase(tester, db);

        final month = top(tester, find.textContaining('This month'));
        final plans = top(tester, find.text('Plans and loans'));
        final spending = top(tester, find.text('Top spending'));
        final recent = top(tester, find.text('Recent'));

        expect(month, lessThan(plans));
        expect(plans, lessThan(spending));
        expect(spending, lessThan(recent));
        // The loans card is one of the plans.
        expect(find.text('Loans'), findsWidgets);
      },
    );

    testWithDatabase(
      'the shortcuts and what you can spend come before the month',
      (tester, db) async {
        useTallScreen(tester);
        await seedBasics(db);
        await pumpAppWithDatabase(tester, db);

        final shortcuts = top(
          tester,
          find.byKey(const ValueKey('shortcut-loans')),
        );
        final month = top(tester, find.textContaining('This month'));

        expect(shortcuts, lessThan(month));
      },
    );
  });

  group('habits, tips and fun', () {
    testWithDatabase('is closed until it is opened', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('home-more')), findsOneWidget);
      expect(find.text('Habits, tips and fun'), findsOneWidget);
      expect(find.byType(TakkaCard), findsNothing);
    });

    testWithDatabase('opens with a tap, and the choice is kept', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(const ValueKey('home-more')));
      await tester.pumpAndSettle();

      expect(find.byType(TakkaCard), findsOneWidget);
      expect((await db.settingsDao.getAll())['home_more_open'], 'true');

      await tester.tap(find.byKey(const ValueKey('home-more')));
      await tester.pumpAndSettle();

      expect(find.byType(TakkaCard), findsNothing);
      expect((await db.settingsDao.getAll())['home_more_open'], 'false');
    });

    testWithDatabase('starts open when it was left open', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await db.settingsDao.put('home_more_open', 'true');
      await pumpAppWithDatabase(tester, db);

      expect(find.byType(TakkaCard), findsOneWidget);
    });

    testWithDatabase('is the last thing on Home', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      expect(
        top(tester, find.text('Recent')),
        lessThan(top(tester, find.byKey(const ValueKey('home-more')))),
      );
    });
  });
}
