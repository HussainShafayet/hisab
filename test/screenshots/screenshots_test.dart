// Draws the main screens to PNG files in build/screenshots/, so they can be
// looked at without a phone or an emulator.
//
//   SCREENSHOTS=1 flutter test test/screenshots
//
// It is skipped in a normal `flutter test`. It loads Roboto and the Material
// icons from the Flutter SDK, and a Bengali font from the system, so that
// the taka sign is drawn instead of an empty box.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/router/app_router.dart';
import 'package:hishab/core/theme/app_theme.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../helpers/fixtures.dart';
import '../helpers/fonts.dart';
import '../helpers/pump_app.dart';

final _enabled = Platform.environment['SCREENSHOTS'] == '1';

/// The app with a font fallback for the taka sign.
class _ShotApp extends ConsumerWidget {
  const _ShotApp();

  ThemeData _withFallback(ThemeData theme) {
    const fallback = ['NotoSansBengali'];
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamilyFallback: fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: _withFallback(AppTheme.light()),
      darkTheme: _withFallback(AppTheme.dark()),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<int> _categoryId(AppDatabase db, String name) async =>
    (await db.categoriesDao.getAll()).firstWhere((c) => c.name == name).id;

Future<void> _seed(AppDatabase db) async {
  final accounts = {
    for (final a in await db.accountsDao.getAll()) a.name: a.id,
  };
  Future<void> setOpening(String name, int poisha) =>
      (db.update(db.accounts)..where((a) => a.id.equals(accounts[name]!)))
          .write(AccountsCompanion(openingBalance: Value(poisha)));
  await setOpening('Cash', 150000);
  await setOpening('bKash', 80000);
  await setOpening('Bank', 2500000);

  Future<void> add(
    TransactionType type,
    int amount,
    String account,
    DateTime date, {
    String? category,
    String? toAccount,
    String note = '',
  }) async => addTransaction(
    db,
    type: type,
    amount: amount,
    accountId: accounts[account]!,
    toAccountId: toAccount == null ? null : accounts[toAccount],
    categoryId: category == null ? null : await _categoryId(db, category),
    date: date,
    note: note,
  );

  const expense = TransactionType.expense;
  await add(
    expense,
    480000,
    'Bank',
    DateTime(2026, 10, 4, 12),
    category: 'Groceries',
    note: 'Bazar',
  );
  await add(
    expense,
    90000,
    'Cash',
    DateTime(2026, 10, 6, 9),
    category: 'Ride sharing',
  );
  await add(
    TransactionType.income,
    4500000,
    'Bank',
    DateTime(2026, 10, 1, 10),
    category: 'Salary',
  );
  await add(
    expense,
    1200000,
    'Bank',
    DateTime(2026, 10, 9, 9),
    category: 'Rent',
    note: 'October rent',
  );
  await add(
    TransactionType.transfer,
    500000,
    'Bank',
    DateTime(2026, 10, 9, 10),
    toAccount: 'bKash',
  );
  await add(
    expense,
    280000,
    'Nagad',
    DateTime(2026, 10, 5, 18),
    category: 'Shopping',
  );
  await add(
    expense,
    29900,
    'bKash',
    DateTime(2026, 10, 10, 12),
    category: 'Mobile recharge',
  );
  await add(
    expense,
    124050,
    'bKash',
    DateTime(2026, 10, 10, 19, 45),
    category: 'Groceries',
    note: 'Weekly bazar',
  );
  await add(
    expense,
    6000,
    'Cash',
    DateTime(2026, 10, 11, 8, 20),
    category: 'Bus & rickshaw',
    note: 'Rickshaw',
  );
  await add(
    expense,
    35000,
    'Cash',
    DateTime(2026, 10, 11, 13, 10),
    category: 'Restaurants',
    note: 'Lunch with Rahim',
  );

  Future<void> budget(int amount, {String? category}) async =>
      db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          amount: amount,
          categoryId: Value(
            category == null ? null : await _categoryId(db, category),
          ),
        ),
      );
  await budget(4000000); // overall: 40,000
  await budget(800000, category: 'Food'); // 8,000
  await budget(100000, category: 'Transport'); // 1,000
  await budget(1200000, category: 'Rent'); // 12,000, exactly used
  await budget(300000, category: 'Shopping'); // 3,000
}

Future<GlobalKey> _pump(WidgetTester tester, AppDatabase db) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => testNow),
      ],
      child: RepaintBoundary(key: key, child: const _ShotApp()),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWithDatabase('screenshots', skip: !_enabled, seedDefaults: true, (
    tester,
    db,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _seed(db);

    final key = await _pump(tester, db);

    await _capture(tester, key, '0_home');
    // Scroll Home to see the top categories and the recent transactions.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await _capture(tester, key, '0_home_scrolled');

    await _openTab(tester, 'Transactions');
    await _capture(tester, key, '1_transactions');

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await _capture(tester, key, '2_filter');
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    for (final k in '1200+350.5×2'.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$k')));
    }
    await tester.tap(
      find.byKey(ValueKey('category-${await _categoryId(db, 'Groceries')}')),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '3_add_transaction');

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await _capture(tester, key, '4_add_transfer');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await _openTab(tester, 'Budget');
    await _capture(tester, key, '8_budget');

    await _openTab(tester, 'Reports');
    await _capture(tester, key, '9_reports');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
    await tester.pumpAndSettle();
    await _capture(tester, key, '9_reports_charts');

    await _openTab(tester, 'More');
    await tester.tap(listRow('Accounts'));
    await tester.pumpAndSettle();
    await _capture(tester, key, '5_accounts');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(listRow('Categories'));
    await tester.pumpAndSettle();
    await _capture(tester, key, '6_categories');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await _openTab(tester, 'Transactions');
    await _capture(tester, key, '7_transactions_dark');
  });
}
