import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

Future<void> spend(
  AppDatabase db,
  Basics b,
  int day,
  int amount, {
  Feeling? feeling,
}) => TransactionsRepository(db)
    .addTransaction(
      TransactionInput(
        type: TransactionType.expense,
        amount: amount,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, day, 12),
        feeling: feeling,
        note: day == 9 ? 'Big dinner' : '',
      ),
    )
    .then((_) {});

Future<void> openWrapped(WidgetTester tester) async {
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Month wrapped'));
  await tester.pumpAndSettle();
}

Future<void> swipe(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('wrapped-pages')),
    const Offset(-600, 0),
  );
  await tester.pumpAndSettle();
}

String big(WidgetTester tester, int i) =>
    tester.widget<Text>(find.byKey(ValueKey('wrapped-big-$i'))).data!;

/// Taps Share and waits until it is done. Drawing the card as a picture needs
/// real time, not the test clock.
Future<void> tapShare(WidgetTester tester) async {
  final share = find.byKey(const ValueKey('wrapped-share'));
  await tester.runAsync(() async {
    await tester.tap(share);
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      // The button is switched off while the card is being sent.
      if (tester.widget<IconButton>(share).onPressed != null) break;
    }
  });
  await tester.pump();
}

void main() {
  testWithDatabase('an empty month says nothing was written', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openWrapped(tester);

    expect(find.text('Nothing written yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('wrapped-done')), findsOneWidget);
  });

  testWithDatabase('swipes through the cards of the month', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await addTransaction(
      db,
      type: TransactionType.income,
      amount: 5000000,
      accountId: b.cash,
      categoryId: b.salary,
      date: DateTime(2026, 10, 1, 9),
    );
    await spend(db, b, 5, 100000, feeling: Feeling.need);
    await spend(db, b, 9, 300000, feeling: Feeling.regret);
    await pumpAppWithDatabase(tester, db);
    await openWrapped(tester);

    // 1: who you were.
    expect(big(tester, 0), 'The Foodie');
    await swipe(tester);
    // 2: money in, money out: 4,000 spent.
    expect(big(tester, 1), '৳4,000.00');
    expect(find.textContaining('You kept ৳46,000.00'), findsOneWidget);
    await swipe(tester);
    // 3: the top category.
    expect(big(tester, 2), 'Food');
    await swipe(tester);
    // 4: the biggest single spend.
    expect(big(tester, 3), '৳3,000.00');
    expect(find.textContaining('Big dinner'), findsOneWidget);
    await swipe(tester);
    // 5: the days: 3 entries, and the days with no spending up to yesterday.
    expect(big(tester, 4), '3 entries');
    await swipe(tester);
    // 6: how it felt.
    expect(big(tester, 5), '৳3,000.00');
    await swipe(tester);
    // 7: the end.
    expect(find.byKey(const ValueKey('wrapped-done')), findsOneWidget);
    expect(find.text('See you next month!'), findsOneWidget);
  });

  group('sharing a card', () {
    testWithDatabase('sends the card on screen as a PNG picture', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, 5, 100000);
      final gateway = FakeFileGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openWrapped(tester);
      await swipe(tester);

      await tapShare(tester);

      final file = gateway.shared.single;
      expect(file.mimeType, 'image/png');
      // The second card of October 2026.
      expect(file.fileName, 'hishab-wrapped-2026-10-2.png');
      expect(file.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWithDatabase('says so when the share sheet cannot open', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, 5, 100000);
      final gateway = FakeFileGateway()..failure = StateError('no sheet');
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openWrapped(tester);

      await tapShare(tester);

      expect(find.text('Could not open the share sheet.'), findsOneWidget);
      expect(gateway.shared, isEmpty);
    });

    testWithDatabase('has no Share button for an empty month', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openWrapped(tester);

      expect(find.byKey(const ValueKey('wrapped-share')), findsNothing);
    });
  });

  group('on Home', () {
    testWithDatabase('has no wrapped card in the middle of the month', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, 5, 100000);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('wrapped-card')), findsNothing);
    });

    testWithDatabase('offers the wrapped at the end of the month', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, 5, 100000);
      await pumpAppWithDatabase(tester, db, now: DateTime(2026, 10, 30, 10));

      expect(find.byKey(const ValueKey('wrapped-card')), findsOneWidget);
      expect(find.text('Your October 2026 wrapped is ready'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wrapped-card')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wrapped-pages')), findsOneWidget);
    });

    testWithDatabase('offers nothing when the month had no entries', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db, now: DateTime(2026, 10, 30, 10));

      expect(find.byKey(const ValueKey('wrapped-card')), findsNothing);
    });
  });
}
