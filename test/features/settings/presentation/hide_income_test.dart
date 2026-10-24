import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/presentation/providers/income_privacy_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
final hiddenIncome = find.byKey(const ValueKey('hidden-income'));

/// ৳1,000 earned and ৳250 spent, so a quarter of the income is gone.
Future<void> earnedAndSpent(AppDatabase db, {bool hide = true}) async {
  final b = await seedBasics(db);
  await addTransaction(
    db,
    type: TransactionType.income,
    amount: 100000,
    accountId: b.cash,
    categoryId: b.salary,
    date: DateTime(2026, 10, 2, 9),
    note: 'Pay',
  );
  await addTransaction(
    db,
    type: TransactionType.expense,
    amount: 25000,
    accountId: b.cash,
    categoryId: b.food,
    date: DateTime(2026, 10, 3, 9),
  );
  if (hide) {
    await SettingsRepository(db).update((p) => p.copyWith(hideIncome: true));
  }
}

Future<void> openTransactions(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Transactions'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('hiding income', () {
    testWithDatabase('is off until it is switched on', (tester, db) async {
      useTallScreen(tester);
      await earnedAndSpent(db, hide: false);
      await pumpAppWithDatabase(tester, db);
      await openTransactions(tester);

      expect(hiddenIncome, findsNothing);
      expect(find.text('+৳1,000.00'), findsWidgets);
    });

    testWithDatabase('shows dots and a bar instead of the income', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await earnedAndSpent(db);
      await pumpAppWithDatabase(tester, db);
      await openTransactions(tester);

      expect(hiddenIncome, findsWidgets);
      expect(find.text('+৳1,000.00'), findsNothing);
      expect(find.text('৳1,000.00'), findsNothing);
      // The expense is not a secret.
      expect(find.text('-৳250.00'), findsWidgets);
      // The bar says a quarter of the income is spent.
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('income-spent-bar')),
      );
      expect(bar.value, 0.25);
    });

    testWithDatabase('also hides the balance of the period', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await earnedAndSpent(db);
      await pumpAppWithDatabase(tester, db);
      await openTransactions(tester);

      // Income minus expense would give the income away.
      expect(find.text('৳750.00'), findsNothing);
    });

    testWithDatabase('is hidden on Home too', (tester, db) async {
      useTallScreen(tester);
      await earnedAndSpent(db);
      await pumpAppWithDatabase(tester, db);

      expect(hiddenIncome, findsWidgets);
      expect(find.text('+৳1,000.00'), findsNothing);
      expect(find.text('৳1,000.00'), findsNothing);
    });

    testWithDatabase('shows for a few seconds when tapped', (tester, db) async {
      useTallScreen(tester);
      await earnedAndSpent(db);
      await pumpAppWithDatabase(tester, db);
      await openTransactions(tester);

      await tester.tap(hiddenIncome.first);
      await tester.pump();
      expect(find.text('৳1,000.00'), findsOneWidget);
      expect(hiddenIncome, findsNothing);

      await tester.pump(incomeRevealDuration + const Duration(seconds: 1));
      expect(find.text('৳1,000.00'), findsNothing);
      expect(hiddenIncome, findsWidgets);
    });

    testWithDatabase('has a switch in Settings that is saved', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Settings');
      final toggle = find.byKey(const ValueKey('hide-income'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect((await SettingsRepository(db).load()).hideIncome, isTrue);
    });
  });
}
