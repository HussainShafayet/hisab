import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

void main() {
  group('Get started on Home', () {
    testWithDatabase('counts what is done and goes when put away', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 1000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 5),
      );
      await pumpAppWithDatabase(tester, db);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('setup-count'))).data,
        'Get started: 1 of 4',
      );

      await tester.tap(find.byKey(const ValueKey('setup-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup-checklist')), findsNothing);
    });
  });

  group('choosing what Home shows', () {
    testWithDatabase('a part can be put away and brought back', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      expect(find.text('Top spending'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-customize')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-section-topSpending')));
      await tester.pumpAndSettle();
      expect((await db.settingsDao.getAll())['home_hidden'], 'topSpending');

      await tester.tap(find.byKey(const ValueKey('home-section-topSpending')));
      await tester.pumpAndSettle();
      expect((await db.settingsDao.getAll())['home_hidden'], '');
    });
  });
}
