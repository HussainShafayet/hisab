import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/fun/domain/quips.dart';
import 'package:hishab/features/fun/domain/takka_mood.dart';
import 'package:hishab/features/fun/presentation/widgets/takka.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

const _card = ValueKey('takka-card');

String said(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(_card), matching: find.byType(Text)),
    )
    .data!;

TakkaMood face(WidgetTester tester) =>
    tester.widget<Takka>(find.byType(Takka).first).mood;

Future<void> pumpHomeWithFunOff(WidgetTester tester, AppDatabase db) async {
  const off = AppPreferences(funMode: false);
  await SettingsRepository(db).save(off);
  await pumpAppWithDatabase(
    tester,
    db,
    overrides: [initialPreferencesProvider.overrideWithValue(off)],
  );
}

void main() {
  group('on Home', () {
    testWithDatabase('Takka says something, with a face', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await showHomeExtras(db);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(_card), findsOneWidget);
      expect(find.byType(Takka), findsOneWidget);
      expect(allQuips, contains(said(tester)));
    });

    testWithDatabase('worries when an account is below zero', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: 25000,
          accountId: b.cash,
          categoryId: Value(b.food),
          date: DateTime(2026, 10, 5),
        ),
      );
      await showHomeExtras(db);
      await pumpAppWithDatabase(tester, db);

      expect(face(tester), TakkaMood.worried);
      expect(said(tester), contains(RegExp('below zero|taka nai|Below zero')));
    });

    testWithDatabase('says another line when tapped', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await showHomeExtras(db);
      await pumpAppWithDatabase(tester, db);
      final first = said(tester);

      await tester.tap(find.byType(Takka));
      await tester.pumpAndSettle();

      expect(said(tester), isNot(first));
      expect(allQuips, contains(said(tester)));
    });

    testWithDatabase('is not there when Fun mode is off', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpHomeWithFunOff(tester, db);

      expect(find.byKey(_card), findsNothing);
      expect(find.byType(Takka), findsNothing);
    });
  });

  group('on an empty screen', () {
    testWithDatabase('Takka keeps the screen company', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.text('Transactions').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing recorded in'), findsOneWidget);
      expect(find.byType(Takka), findsWidgets);
      expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
    });

    testWithDatabase('the plain icon is there when Fun mode is off', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpHomeWithFunOff(tester, db);
      await tester.tap(find.text('Transactions').last);
      await tester.pumpAndSettle();

      expect(find.byType(Takka), findsNothing);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });
  });
}
