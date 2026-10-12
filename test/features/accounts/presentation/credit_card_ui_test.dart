import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';

import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

Account creditCard({int? limit, int? day}) => Account(
  id: 1,
  name: 'Visa',
  type: AccountType.creditCard,
  openingBalance: 0,
  includeInTotal: true,
  isArchived: false,
  creditLimit: limit,
  billDueDay: day,
);

Future<void> pumpCard(WidgetTester tester, Widget card) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: card),
    ),
  ),
);

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<int> makeCard(
  AppDatabase db, {
  int owed = 50000,
  int? limit = 200000,
  int? day = 15,
}) => db.accountsDao.insertAccount(
  AccountsCompanion.insert(
    name: 'Visa',
    type: AccountType.creditCard,
    openingBalance: Value(-owed),
    creditLimit: Value(limit),
    billDueDay: Value(day),
  ),
);

Future<void> openAccountForm(WidgetTester tester) async {
  await openFromMore(tester, 'Accounts');
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  group('the account card of a credit card', () {
    testWidgets('shows what is owed, not a negative balance', (tester) async {
      await pumpCard(
        tester,
        AccountCard(account: creditCard(), balance: -125000),
      );

      expect(find.text('Owed'), findsOneWidget);
      expect(find.text('Balance'), findsNothing);
      expect(textOf(tester, 'balance-1'), '৳1,250.00');
    });

    testWidgets('says "In credit" when more was paid than owed', (
      tester,
    ) async {
      await pumpCard(tester, AccountCard(account: creditCard(), balance: 4000));

      expect(find.text('In credit'), findsOneWidget);
      expect(textOf(tester, 'balance-1'), '৳40.00');
    });

    testWidgets('shows what is left to spend under the limit', (tester) async {
      await pumpCard(
        tester,
        AccountCard(account: creditCard(limit: 200000), balance: -50000),
      );

      expect(textOf(tester, 'limit-left'), '৳1,500.00 left to spend');
      expect(find.text('Limit ৳2,000.00'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('says when it is over the limit', (tester) async {
      await pumpCard(
        tester,
        AccountCard(account: creditCard(limit: 200000), balance: -250000),
      );

      expect(textOf(tester, 'limit-left'), 'Over the limit by ৳500.00');
    });

    testWidgets('has no limit line without a limit', (tester) async {
      await pumpCard(
        tester,
        AccountCard(account: creditCard(), balance: -50000),
      );

      expect(find.byKey(const ValueKey('limit-left')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows what will be owed after a purchase', (tester) async {
      await pumpCard(
        tester,
        AccountCard(
          account: creditCard(limit: 200000),
          balance: -50000,
          balanceAfter: -80000,
        ),
      );

      expect(find.text('Owed after this'), findsOneWidget);
      expect(find.text('After this'), findsNothing);
      expect(textOf(tester, 'balance-after-1'), '৳800.00');
      // Owing is normal for a card: no warning below the limit.
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('warns when a purchase goes over the limit', (tester) async {
      await pumpCard(
        tester,
        AccountCard(
          account: creditCard(limit: 200000),
          balance: -150000,
          balanceAfter: -250000,
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('does not warn about a card without a limit', (tester) async {
      await pumpCard(
        tester,
        AccountCard(account: creditCard(), balance: 0, balanceAfter: -999999),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('the account form', () {
    testWithDatabase('asks for a limit and a bill day only for a credit card', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openAccountForm(tester);

      expect(find.byKey(const ValueKey('credit-limit')), findsNothing);
      expect(find.byKey(const ValueKey('bill-due-day')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('type-creditCard')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('credit-limit')), findsOneWidget);
      expect(find.byKey(const ValueKey('bill-due-day')), findsOneWidget);
      expect(find.text('Already owed on this card'), findsOneWidget);
      expect(find.text('Opening balance'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('type-bank')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('credit-limit')), findsNothing);
      expect(find.text('Opening balance'), findsOneWidget);
    });

    testWithDatabase('saves what is owed as a balance below zero', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final scheduler = FakeReminderScheduler();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      );
      await openAccountForm(tester);

      await tester.tap(find.byKey(const ValueKey('type-creditCard')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Visa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Already owed on this card'),
        '500',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Credit limit (optional)'),
        '2000',
      );
      await tester.tap(find.byKey(const ValueKey('bill-due-day')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day 15 of every month').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      final card = (await db.accountsDao.getAll()).firstWhere(
        (a) => a.name == 'Visa',
      );
      expect(card.type, AccountType.creditCard);
      expect(card.openingBalance, -50000);
      expect(card.creditLimit, 200000);
      expect(card.billDueDay, 15);
      // The bill day sets the reminders.
      expect(
        scheduler.scheduled.map((r) => r.title),
        contains('Credit card bill due today'),
      );
    });

    testWithDatabase('shows the card with what is owed while it is made', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openAccountForm(tester);

      await tester.tap(find.byKey(const ValueKey('type-creditCard')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Already owed on this card'),
        '500',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Credit limit (optional)'),
        '2000',
      );
      await tester.pump();

      expect(find.text('Owed'), findsOneWidget);
      expect(textOf(tester, 'limit-left'), '৳1,500.00 left to spend');
    });

    testWithDatabase('keeps the meaning of the money when the kind changes', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openAccountForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance'),
        '500',
      );
      await tester.tap(find.byKey(const ValueKey('type-creditCard')));
      await tester.pumpAndSettle();

      // ৳500 held is -500 owed.
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Already owed on this card'),
            )
            .controller!
            .text,
        '-500',
      );
    });

    testWithDatabase('opens a saved card with what is owed as a plain number', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await makeCard(db, owed: 50000, limit: 200000, day: 15);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await tester.tap(find.text('Visa'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Already owed on this card'),
            )
            .controller!
            .text,
        '500',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Credit limit (optional)'),
            )
            .controller!
            .text,
        '2000',
      );
      expect(find.text('Day 15 of every month'), findsOneWidget);
    });

    testWithDatabase('turning a card into another kind drops the limit', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await makeCard(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await tester.tap(find.text('Visa'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('type-bank')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      final account = (await db.accountsDao.getById(id))!;
      expect(account.type, AccountType.bank);
      expect(account.creditLimit, isNull);
      expect(account.billDueDay, isNull);
      // And what was owed is a balance below zero still.
      expect(account.openingBalance, -50000);
    });
  });

  group('spending with a credit card', () {
    testWithDatabase('shows what will be owed after the purchase', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 50000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '300');

      expect(find.text('Owed after this'), findsOneWidget);
      expect(textOf(tester, 'balance-after-$card'), '৳800.00');
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWithDatabase('warns when the purchase is over the limit', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 150000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '800');

      expect(textOf(tester, 'balance-after-$card'), '৳2,300.00');
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
