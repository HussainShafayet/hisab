import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

final noteField = find.byKey(const ValueKey('note-field'));
final suggestions = find.byKey(const ValueKey('note-suggestions'));

Future<void> addPast(
  dynamic db,
  Basics basics,
  String note, {
  int amount = 35000,
  int? category,
}) => addTransaction(
  db,
  type: TransactionType.expense,
  amount: amount,
  accountId: basics.cash,
  categoryId: category ?? basics.food,
  date: DateTime(2026, 10, 5),
  note: note,
);

void main() {
  group('note suggestions on the add form', () {
    testWithDatabase('offer earlier notes that match what is typed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final basics = await seedBasics(db);
      await addPast(db, basics, 'Lunch with Rahim');
      await addPast(db, basics, 'Rickshaw', amount: 6000);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await tester.tap(noteField);
      await tester.enterText(noteField, 'lun');
      await tester.pump();

      expect(suggestions, findsOneWidget);
      expect(find.text('Lunch with Rahim'), findsOneWidget);
      expect(find.text('Rickshaw'), findsNothing);
    });

    testWithDatabase('are not shown before the note is touched', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final basics = await seedBasics(db);
      await addPast(db, basics, 'Lunch with Rahim');
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(suggestions, findsNothing);
    });

    testWithDatabase('fill the note, the category and the amount', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final basics = await seedBasics(db);
      await addPast(db, basics, 'Lunch with Rahim');
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tester.tap(noteField);
      await tester.enterText(noteField, 'lun');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('note-suggestion-0')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(noteField).controller!.text,
        'Lunch with Rahim',
      );
      expect(amountText(tester), '350');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-field')),
          matching: find.text('Food'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('keep an amount that was already typed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final basics = await seedBasics(db);
      await addPast(db, basics, 'Lunch with Rahim');
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await typeAmount(tester, '90');
      await tester.tap(noteField);
      await tester.enterText(noteField, 'lun');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('note-suggestion-0')));
      await tester.pumpAndSettle();

      expect(amountText(tester), '90');
    });
  });
}
