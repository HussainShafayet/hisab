import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

final quickField = find.byKey(const ValueKey('quick-type-field'));
final quickApply = find.byKey(const ValueKey('quick-type-apply'));

void main() {
  group('the quick-type line of the add form', () {
    testWithDatabase('fills the amount, the account and the category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.enterText(quickField, 'transport 50 bkash');
      await tester.pump();
      expect(find.byKey(const ValueKey('quick-type-preview')), findsOneWidget);

      await tester.tap(quickApply);
      await tester.pumpAndSettle();

      expect(amountText(tester), '50');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-field')),
          matching: find.text('bKash'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-field')),
          matching: find.text('Transport'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('form-notice')), findsOneWidget);
    });

    testWithDatabase('turns the form into an income for +salary', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.enterText(quickField, '+salary 30k');
      await tester.pump();
      await tester.tap(quickApply);
      await tester.pumpAndSettle();

      expect(amountText(tester), '30000');
      expect(find.text(TransactionType.income.name), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-field')),
          matching: find.text('Salary'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('cannot be applied while it understands nothing', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(tester.widget<IconButton>(quickApply).onPressed, isNull);
      expect(find.byKey(const ValueKey('quick-type-preview')), findsNothing);
    });
  });

  group('a day in the quick-type line', () {
    testWithDatabase('shows the day and sets it in the form', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.enterText(quickField, 'transport 50 gotokal');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quick-type-preview')),
          matching: find.text('Yesterday'),
        ),
        findsOneWidget,
      );

      await tester.tap(quickApply);
      await tester.pumpAndSettle();

      final yesterday = find.widgetWithText(ChoiceChip, 'Yesterday');
      expect(tester.widget<ChoiceChip>(yesterday).selected, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Today'))
            .selected,
        isFalse,
      );
    });
  });
}
