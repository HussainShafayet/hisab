import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

final pasteSms = find.byKey(const ValueKey('paste-sms'));

/// Puts [text] on the clipboard the form reads (null: nothing copied).
void copied(WidgetTester tester, String? text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return text == null ? null : <String, dynamic>{'text': text};
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

const cashOutSms =
    'Cash Out Tk 500.00 to 01712345678 successful. Fee Tk 9.25. '
    'Balance Tk 700.00. TrxID 9GH7K2L2 at 10/10/2026 15:01';

String noteText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('note-field')))
    .controller!
    .text;

void main() {
  group('pasting an SMS on the add form', () {
    testWithDatabase('turns a cash out into a transfer with its fee', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Cash');
      await insertTestAccount(
        db,
        name: 'bKash',
        type: AccountType.mobileBanking,
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      copied(tester, cashOutSms);

      await tester.tap(pasteSms);
      await tester.pumpAndSettle();

      expect(amountText(tester), '500');
      expect(noteText(tester), 'Cash out · 01712345678 · TrxID 9GH7K2L2');
      expect(
        tester
            .widget<SegmentedButton<TransactionType>>(
              find.byType(SegmentedButton<TransactionType>),
            )
            .selected,
        {TransactionType.transfer},
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('from-field')),
          matching: find.text('bKash'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('to-field')),
          matching: find.text('Cash'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('form-notice')), findsOneWidget);
    });

    testWithDatabase('says when the balance does not match the SMS', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Cash');
      await insertTestAccount(
        db,
        name: 'bKash',
        type: AccountType.mobileBanking,
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      copied(tester, cashOutSms);

      await tester.tap(pasteSms);
      await tester.pumpAndSettle();

      // The app knows of no money in bKash, the SMS says ৳700.00 is left.
      expect(find.textContaining('Something may be missing'), findsOneWidget);
    });

    testWithDatabase('puts the date of the message on the form', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Cash');
      await insertTestAccount(
        db,
        name: 'bKash',
        type: AccountType.mobileBanking,
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      copied(tester, cashOutSms);

      await tester.tap(pasteSms);
      await tester.pumpAndSettle();

      // The message is from the 10th and today is the 11th.
      final yesterday = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Yesterday'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(yesterday.selected, isTrue);
    });

    testWithDatabase('does not add the same SMS twice', (tester, db) async {
      useTallScreen(tester);
      final basics = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.transfer,
        amount: 50000,
        accountId: basics.bkash,
        toAccountId: basics.cash,
        date: DateTime(2026, 10, 10),
        note: 'Cash out · 01712345678 · TrxID 9GH7K2L2',
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      copied(tester, cashOutSms);

      await tester.tap(pasteSms);
      await tester.pumpAndSettle();

      expect(find.textContaining('Already in your records'), findsOneWidget);
      expect(amountText(tester), isEmpty);
    });

    testWithDatabase('asks to copy the SMS when nothing is copied', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      copied(tester, null);

      await tester.tap(pasteSms);
      await tester.pumpAndSettle();

      expect(find.textContaining('Copy the bKash'), findsOneWidget);
    });

    testWithDatabase('says so when the text is not a money SMS', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      copied(tester, 'see you at 5');

      await tester.tap(pasteSms);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('does not look like a message about money'),
        findsOneWidget,
      );
      expect(amountText(tester), isEmpty);
    });
  });
}
