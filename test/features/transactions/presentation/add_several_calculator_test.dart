import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

// Each row of Add several has a calculator button in its amount field.

Future<void> openAddSeveral(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-several')));
  await tester.pumpAndSettle();
}

String rowAmount(WidgetTester tester, int row) => tester
    .widget<TextField>(find.byKey(ValueKey('row-amount-$row')))
    .controller!
    .text;

Future<void> openCalculator(WidgetTester tester, int row) async {
  await tester.tap(find.byKey(ValueKey('row-calculator-$row')));
  await tester.pumpAndSettle();
}

String display(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('calc-display'))).data!;

void main() {
  group('the calculator of Add several', () {
    testWithDatabase('adds up a sum and puts the result in the amount', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await openCalculator(tester, 0);
      await tapCalcKeys(tester, '1200+350');
      expect(display(tester), '1200+350');
      expect(find.text('= ৳1,550.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calc-use')));
      await tester.pumpAndSettle();

      expect(rowAmount(tester, 0), '1550');
    });

    testWithDatabase('starts from what is already in the amount', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);
      await tester.enterText(find.byKey(const ValueKey('row-amount-0')), '450');
      await tester.pump();

      await openCalculator(tester, 0);
      await tapCalcKeys(tester, '×3');
      await tester.tap(find.byKey(const ValueKey('calc-use')));
      await tester.pumpAndSettle();

      expect(rowAmount(tester, 0), '1350');
    });

    testWithDatabase('leaves the amount alone when it is closed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);
      await tester.enterText(find.byKey(const ValueKey('row-amount-0')), '99');
      await tester.pump();

      await openCalculator(tester, 0);
      await tapCalcKeys(tester, '+1');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(rowAmount(tester, 0), '99');
    });

    testWithDatabase('cannot be used before the sum is a number', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);

      await openCalculator(tester, 0);

      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('calc-use')))
            .enabled,
        isFalse,
      );
    });

    testWithDatabase('clears the sum', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddSeveral(tester);
      await openCalculator(tester, 0);
      await tapCalcKeys(tester, '12+5');

      await tester.tap(find.byKey(const ValueKey('calc-clear')));
      await tester.pump();

      expect(display(tester), '0');
    });
  });
}
