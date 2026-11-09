import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

Future<int> makeCard(AppDatabase db, {required int owed, int? limit}) =>
    db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: 'Visa',
        type: AccountType.creditCard,
        openingBalance: Value(-owed),
        creditLimit: Value(limit),
        billDueDay: const Value(15),
      ),
    );

void main() {
  group('a late fee or charge on a credit card', () {
    testWithDatabase('opens the add form on the card with the fee filled in', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 50000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await tester.tap(find.byKey(ValueKey('add-charge-$card')));
      await tester.pumpAndSettle();
      expect(find.text('What did the bank charge?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('card-charge-late')));
      await tester.pumpAndSettle();

      expect(find.text('Add transaction'), findsOneWidget);
      expect(categoryShown(tester), contains('Late fee'));
      expect(find.text('Late payment fee'), findsOneWidget);
      expect(find.text('Visa'), findsWidgets);
    });

    testWithDatabase('is there for a card that owes nothing too', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 0);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.byKey(ValueKey('add-charge-$card')), findsOneWidget);
      expect(find.byKey(ValueKey('pay-bill-$card')), findsNothing);
    });

    testWithDatabase('a charge makes the owed amount bigger', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 50000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await tester.tap(find.byKey(ValueKey('add-charge-$card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-charge-annual')));
      await tester.pumpAndSettle();

      await typeAmount(tester, '1150');

      expect(find.text('Owed after this'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey('balance-after-$card'))).data,
        '৳1,650.00',
      );
    });
  });

  group('a card over its limit', () {
    testWithDatabase('says by how much, and offers three ways on', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 250000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.byKey(ValueKey('card-over-limit-$card')), findsOneWidget);
      expect(
        find.text('৳500.00 is over the limit of this card.'),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('pay-extra-$card')), findsOneWidget);
      expect(find.byKey(ValueKey('raise-limit-$card')), findsOneWidget);
      expect(find.byKey(ValueKey('add-charge-$card')), findsOneWidget);
    });

    testWithDatabase('Pay the extra opens a transfer into the card', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 250000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await tester.tap(find.byKey(ValueKey('pay-extra-$card')));
      await tester.pumpAndSettle();

      expect(find.text('Add transaction'), findsOneWidget);
      expect(amountText(tester), startsWith('500'));
    });

    testWithDatabase('says nothing while the card is within its limit', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 50000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.byKey(ValueKey('card-over-limit-$card')), findsNothing);
    });
  });
}
