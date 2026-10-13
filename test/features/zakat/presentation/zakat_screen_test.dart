import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/zakat/data/zakat_settings_repository.dart';

import '../../../helpers/fake_rate_service.dart';
import '../../../helpers/pump_app.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pumpAndSettle();
}

Future<int> account(
  AppDatabase db,
  String name,
  int balance, {
  AccountType type = AccountType.cash,
}) => db.accountsDao.insertAccount(
  AccountsCompanion.insert(
    name: name,
    type: type,
    openingBalance: Value(balance),
  ),
);

Future<void> openZakat(
  WidgetTester tester,
  AppDatabase db, {
  FakeRateService? rates,
}) async {
  await pumpAppWithDatabase(
    tester,
    db,
    overrides: [
      if (rates != null) rateServiceProvider.overrideWithValue(rates),
    ],
  );
  await openFromMore(tester, 'Zakat');
}

void main() {
  group('the zakat screen', () {
    testWithDatabase('asks for the price of a gram first', (tester, db) async {
      useTallScreen(tester);
      await account(db, 'Cash', 10000000);
      await openZakat(tester, db);

      expect(textOf(tester, 'zakat-assets'), '৳100,000.00');
      expect(textOf(tester, 'zakat-nisab'), '-');
      expect(
        find.text('Enter the price of a gram to see if zakat is due.'),
        findsOneWidget,
      );
    });

    testWithDatabase('works out the zakat once there is a nisab', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await account(db, 'Cash', 10000000);
      await openZakat(tester, db);

      await enter(tester, 'zakat-gram', '100');

      expect(textOf(tester, 'zakat-nisab'), '৳61,236.00');
      expect(textOf(tester, 'zakat-net'), '৳100,000.00');
      expect(textOf(tester, 'zakat-due'), '৳2,500.00');
      expect(textOf(tester, 'zakat-result'), '2.5% of ৳100,000.00');
    });

    testWithDatabase('says when the wealth is under the nisab', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await account(db, 'Cash', 4000000);
      await openZakat(tester, db);

      await enter(tester, 'zakat-gram', '100');

      expect(
        textOf(tester, 'zakat-result'),
        'Your wealth is ৳21,236.00 under the nisab, so no zakat is due.',
      );
      expect(find.byKey(const ValueKey('zakat-due')), findsNothing);
    });

    testWithDatabase('leaves out an account that is unticked', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await account(db, 'Cash', 6000000);
      final bank = await account(db, 'Bank', 4000000, type: AccountType.bank);
      await openZakat(tester, db);
      expect(textOf(tester, 'zakat-assets'), '৳100,000.00');

      await tapKey(tester, 'zakat-account-$bank');

      expect(textOf(tester, 'zakat-assets'), '৳60,000.00');
      expect((await ZakatSettingsRepository(db).load()).excludedAccountIds, {
        bank,
      });
    });

    testWithDatabase('does not count a credit card as savings, but as a debt', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await account(db, 'Cash', 10000000);
      final card = await account(
        db,
        'Visa',
        -2000000,
        type: AccountType.creditCard,
      );
      await openZakat(tester, db);

      expect(find.byKey(ValueKey('zakat-account-$card')), findsNothing);
      expect(textOf(tester, 'zakat-assets'), '৳100,000.00');
      expect(textOf(tester, 'zakat-liabilities'), '৳20,000.00');
      expect(textOf(tester, 'zakat-net'), '৳80,000.00');

      await tapKey(tester, 'zakat-subtract-debts');

      expect(textOf(tester, 'zakat-liabilities'), '৳0.00');
      expect(textOf(tester, 'zakat-net'), '৳100,000.00');
    });

    testWithDatabase('adds what people owe you, and takes off what you owe', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await account(db, 'Cash', 5000000);
      final debts = DebtsRepository(db);
      await debts.createDebt(
        person: 'Rahim',
        direction: DebtDirection.lent,
        amount: 3000000,
        openedOn: DateTime(2026, 9, 1),
      );
      await debts.createDebt(
        person: 'Karim',
        direction: DebtDirection.borrowed,
        amount: 1000000,
        openedOn: DateTime(2026, 9, 1),
      );
      await openZakat(tester, db);

      expect(textOf(tester, 'zakat-assets'), '৳80,000.00');
      expect(textOf(tester, 'zakat-liabilities'), '৳10,000.00');

      await tapKey(tester, 'zakat-owed-to-you');
      expect(textOf(tester, 'zakat-assets'), '৳50,000.00');
    });

    testWithDatabase('counts other savings', (tester, db) async {
      useTallScreen(tester);
      await account(db, 'Cash', 1000000);
      await openZakat(tester, db);

      await enter(tester, 'zakat-other', '25000');

      expect(textOf(tester, 'zakat-assets'), '৳35,000.00');
      expect((await ZakatSettingsRepository(db).load()).otherAssets, 2500000);
    });

    testWithDatabase('remembers the price of a gram', (tester, db) async {
      useTallScreen(tester);
      await account(db, 'Cash', 1000000);
      await openZakat(tester, db);

      await enter(tester, 'zakat-gram', '100');

      expect((await ZakatSettingsRepository(db).load()).gramPrice, 10000);
    });

    testWithDatabase('shows the settings that were saved', (tester, db) async {
      useTallScreen(tester);
      await account(db, 'Cash', 10000000);
      await ZakatSettingsRepository(db)
          .save(const ZakatSettings(gramPrice: 10000));
      await openZakat(tester, db);

      expect(textOf(tester, 'zakat-nisab'), '৳61,236.00');
    });

    testWithDatabase('goes by gold when gold is chosen', (tester, db) async {
      useTallScreen(tester);
      await account(db, 'Cash', 100000000);
      await openZakat(tester, db);
      await enter(tester, 'zakat-gram', '100');

      await tapKey(tester, 'zakat-gold');

      // The price of a gram is for the other metal, so it is cleared.
      expect(textOf(tester, 'zakat-nisab'), '-');
      await enter(tester, 'zakat-gram', '10000');
      expect(textOf(tester, 'zakat-nisab'), '৳874,800.00');
    });
  });

  group("today's price", () {
    testWithDatabase('fills the price of a gram from the internet', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await account(db, 'Cash', 10000000);
      final rates = FakeRateService(bdtPerUsd: 120, silver: 60);
      await openZakat(tester, db, rates: rates);

      await tapKey(tester, 'zakat-fetch');

      // $60 an ounce at ৳120 is ৳231.49 a gram.
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('zakat-gram')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '231.49',
      );
      expect(find.byKey(const ValueKey('zakat-fetched')), findsOneWidget);
      expect((await ZakatSettingsRepository(db).load()).gramPrice, 23149);
      expect(rates.calls, 2);
    });

    testWithDatabase('uses the gold price when gold is chosen', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final rates = FakeRateService(bdtPerUsd: 120, gold: 4000, silver: 60);
      await openZakat(tester, db, rates: rates);
      await tapKey(tester, 'zakat-gold');

      await tapKey(tester, 'zakat-fetch');

      // $4,000 an ounce at ৳120 is ৳15,432.30 a gram.
      expect((await ZakatSettingsRepository(db).load()).gramPrice, 1543230);
    });

    testWithDatabase('says so when the internet is not there', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await account(db, 'Cash', 10000000);
      await openZakat(tester, db, rates: FakeRateService(fails: true));

      await tapKey(tester, 'zakat-fetch');

      expect(
        textOf(tester, 'zakat-fetch-error'),
        "Could not get today's rate. Check your internet and try again.",
      );
      expect((await ZakatSettingsRepository(db).load()).gramPrice, isNull);
    });
  });
}
