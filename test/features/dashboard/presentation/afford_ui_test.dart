import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

Future<void> openAfford(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('afford-button')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('afford-button')));
  await tester.pumpAndSettle();
}

String verdict(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('afford-text'))).data!;

void main() {
  testWithDatabase('says whether a price fits, with no budget set', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await addTransaction(
      db,
      type: TransactionType.income,
      amount: 500000,
      accountId: b.cash,
      categoryId: b.salary,
      date: DateTime(2026, 10, 1),
    );
    await pumpAppWithDatabase(tester, db);
    await openAfford(tester);

    expect(find.byKey(const ValueKey('afford-result')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('afford-price')), '100');
    await tester.pump();
    expect(
      verdict(tester),
      'Your accounts can pay for it. ৳4,900.00 would be left.',
    );

    await tester.enterText(find.byKey(const ValueKey('afford-price')), '6000');
    await tester.pump();
    expect(
      verdict(tester),
      'That is ৳1,000.00 more than the money in your accounts.',
    );
  });
}
