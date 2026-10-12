import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_type_ui.dart';

Account account({
  String name = 'bKash',
  AccountType type = AccountType.mobileBanking,
  bool archived = false,
  bool inTotal = true,
}) => Account(
  id: 1,
  name: name,
  type: type,
  openingBalance: 0,
  includeInTotal: inTotal,
  isArchived: archived,
);

Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: card),
    ),
  ),
);

void main() {
  testWidgets('shows the name, the kind and the balance', (tester) async {
    await pump(tester, AccountCard(account: account(), balance: 123450));

    expect(find.text('bKash'), findsOneWidget);
    expect(find.text('Mobile banking'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('৳1,234.50'), findsOneWidget);
    expect(find.text('After this'), findsNothing);
  });

  testWidgets('leaves the balance out while it is not known', (tester) async {
    await pump(tester, AccountCard(account: account()));

    expect(find.text('Balance'), findsNothing);
    expect(find.byKey(const ValueKey('balance-1')), findsNothing);
  });

  testWidgets('shows what the balance will be after', (tester) async {
    await pump(
      tester,
      AccountCard(account: account(), balance: 100000, balanceAfter: 40000),
    );

    expect(find.text('After this'), findsOneWidget);
    expect(find.text('৳400.00'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('warns when the balance after is below zero', (tester) async {
    await pump(
      tester,
      AccountCard(account: account(), balance: 10000, balanceAfter: -5000),
    );

    expect(find.text('-৳50.00'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('shows a caption above the name', (tester) async {
    await pump(tester, AccountCard(account: account(), caption: 'From'));

    expect(find.text('From'), findsOneWidget);
  });

  testWidgets('does not repeat the kind when the name already says it', (
    tester,
  ) async {
    await pump(
      tester,
      AccountCard(
        account: account(name: 'Cash', type: AccountType.cash),
        balance: 1000,
      ),
    );

    // The name only, once.
    expect(find.text('Cash'), findsOneWidget);
  });

  testWidgets('says when an account is archived or not in the total', (
    tester,
  ) async {
    await pump(
      tester,
      AccountCard(account: account(archived: true, inTotal: false)),
    );

    expect(
      find.text('Mobile banking · Archived · Not in total'),
      findsOneWidget,
    );
  });

  testWidgets('marks the chosen card with a check', (tester) async {
    await pump(tester, AccountCard(account: account(), selected: true));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a trailing widget replaces the check', (tester) async {
    await pump(
      tester,
      AccountCard(
        account: account(),
        selected: true,
        trailing: const Icon(Icons.unfold_more),
      ),
    );

    expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('can be tapped', (tester) async {
    var taps = 0;
    await pump(tester, AccountCard(account: account(), onTap: () => taps++));

    await tester.tap(find.byType(AccountCard));

    expect(taps, 1);
  });

  testWidgets('a huge balance and a long name fit a narrow card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });

    await pump(
      tester,
      AccountCard(
        account: account(
          name: 'A savings account with a very long name indeed',
        ),
        balance: 99999999999999,
        balanceAfter: -99999999999999,
        caption: 'From',
      ),
    );

    expect(tester.takeException(), isNull);
  });

  test('every kind of account has its own color', () {
    final colors = {for (final type in AccountType.values) type.color};

    expect(colors, hasLength(AccountType.values.length));
  });
}
