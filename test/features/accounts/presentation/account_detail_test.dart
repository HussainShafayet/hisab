import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';
import 'accounts_screen_test.dart' show accountCard, addAccount;

/// Today is Sunday 11 Oct 2026. Cash: salary in, lunch out, 1,000 moved to
/// bKash; and a lunch last month.
Future<({int cash, int bkash, int lunch})> seed(AppDatabase db) async {
  final cash = await addAccount(db, 'Cash');
  final bkash = await addAccount(db, 'bKash', type: AccountType.mobileBanking);
  final food = await insertTestCategory(db, name: 'Food');
  final pay = await insertTestCategory(
    db,
    name: 'Pay',
    type: CategoryType.income,
  );
  await addTransaction(
    db,
    type: TransactionType.income,
    amount: 5000000,
    accountId: cash,
    categoryId: pay,
    date: DateTime(2026, 10, 2),
  );
  final lunch = await addTransaction(
    db,
    type: TransactionType.expense,
    amount: 25000,
    accountId: cash,
    categoryId: food,
    date: DateTime(2026, 10, 11, 12),
  );
  await addTransaction(
    db,
    type: TransactionType.transfer,
    amount: 100000,
    accountId: cash,
    toAccountId: bkash,
    date: DateTime(2026, 10, 9),
  );
  await addTransaction(
    db,
    type: TransactionType.expense,
    amount: 7000,
    accountId: cash,
    categoryId: food,
    date: DateTime(2026, 9, 20),
  );
  return (cash: cash, bkash: bkash, lunch: lunch);
}

void main() {
  group('the month line on the account cards', () {
    testWithDatabase('says what came in and went out this month', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.textContaining('In ৳50,000.00'), findsOneWidget);
      // Lunch ৳250 and the ৳1,000 moved out; the lunch of September is not in.
      expect(find.textContaining('Out ৳1,250.00'), findsOneWidget);
      expect(find.text('3 entries this month'), findsOneWidget);
      // bKash only received the transfer.
      expect(find.text('1 entry this month'), findsOneWidget);
    });

    testWithDatabase('the total card shows how the money is shared', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.byKey(const ValueKey('share-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-cash')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-mobileBanking')), findsOneWidget);
    });
  });

  group('an account page', () {
    testWithDatabase('opens from the card and shows the month', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final a = await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await tester.tap(accountCard('Cash'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-card')), findsOneWidget);
      final summary = find.byKey(const ValueKey('detail-summary'));
      expect(
        find.descendant(of: summary, matching: find.text('৳50,000.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('৳1,250.00')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('detail-entry-${a.lunch}')), findsOneWidget);
      // Last month's lunch is not in October.
      expect(find.byKey(const ValueKey('detail-empty')), findsNothing);
    });

    testWithDatabase('an account that only received shows the transfer', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await tester.tap(accountCard('bKash'));
      await tester.pumpAndSettle();

      final summary = find.byKey(const ValueKey('detail-summary'));
      expect(
        find.descendant(of: summary, matching: find.text('৳1,000.00')),
        findsWidgets,
      );
      expect(find.text('Transfer'), findsWidgets);
    });

    testWithDatabase('goes back a month', (tester, db) async {
      useTallScreen(tester);
      final a = await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await tester.tap(accountCard('Cash'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('detail-entry-${a.lunch}')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-summary')),
          matching: find.text('৳70.00'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('Expense starts the form on this account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await tester.tap(accountCard('bKash'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('detail-income')));
      await tester.pumpAndSettle();

      expect(find.text('Add transaction'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<TransactionType>>(
              find.byType(SegmentedButton<TransactionType>),
            )
            .selected,
        {TransactionType.income},
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-field')),
          matching: find.text('bKash'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('the pencil edits the account', (tester, db) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await tester.tap(accountCard('Cash'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('detail-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit account'), findsOneWidget);
    });
  });
}
