// Walks every main screen and every screen of the More tab and checks it
// the way Flutter's own accessibility guidelines do: tap targets of at least
// 48 dp and a label on every tap target. (Contrast is checked on the theme's
// colors in test/core/theme/theme_contrast_test.dart: the pixel based guideline
// gives readings far off for text on cards.) It also
// looks for overflow (which Flutter reports as an exception) on a small phone,
// with large text, in dark mode and in Bangla.
//
// A failure names the screen and what is wrong with it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/debt_charge.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../helpers/fixtures.dart';
import '../helpers/fonts.dart';
import '../helpers/pump_app.dart';

/// The rows of the More tab, in English.
const _moreScreens = [
  // First, while the list is still at its top.
  'Help & guide',
  'Accounts',
  'Loans',
  'Investments',
  'Gold & silver',
  'Savings goals',
  'Recurring',
  'Bazar list',
  'Trips & events',
  'Split a bill',
  'Zakat',
  'Insights & habits',
  'Month wrapped',
  'Challenges',
  'Badges',
  'Categories',
  'Data check',
  'Backup & export',
  'Settings',
];

const _tabs = ['Home', 'Transactions', 'Budget', 'Reports'];

/// A little of everything, so the screens have something to show.
Future<void> _seed(AppDatabase db) async {
  final accounts = await db.accountsDao.getAll();
  final categories = await db.categoriesDao.getAll();
  final spendOn = categories.firstWhere((c) => c.type.name == 'expense');
  final earnOn = categories.firstWhere((c) => c.type.name == 'income');
  Future<void> add(TransactionType type, int amount, int category, int day) =>
      addTransaction(
        db,
        type: type,
        amount: amount,
        accountId: accounts.first.id,
        categoryId: category,
        date: DateTime(2026, 10, day, 12),
        note: 'Sample',
      );
  await add(TransactionType.income, 4500000, earnOn.id, 1);
  await add(TransactionType.expense, 125000, spendOn.id, 3);
  await add(TransactionType.expense, 35000, spendOn.id, 8);
  final repo = DebtsRepository(db);
  final taken = await repo.createDebt(
    person: 'Rahim',
    direction: DebtDirection.borrowed,
    amount: 1000000,
    openedOn: DateTime(2026, 10, 1, 10),
    dueOn: DateTime(2026, 10, 9),
    accountId: accounts.first.id,
  );
  await repo.addCharge(
    taken,
    amount: 50000,
    chargedOn: DateTime(2026, 10, 10, 9),
    kind: DebtChargeKind.lateFee,
  );
  await repo.createDebt(
    person: 'Karim',
    direction: DebtDirection.lent,
    amount: 300000,
    openedOn: DateTime(2026, 10, 3, 10),
  );
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(tr(label)),
    ),
  );
  await tester.pumpAndSettle();
}

/// What Flutter reported since the last look (an overflow, for one), with the
/// place in the code it names. Errors are taken here instead of failing the
/// test, so one run lists every screen that has one.
final _reported = <String>[];

void _collectErrors() {
  FlutterError.onError = (details) {
    final text = details.toString();
    final place = RegExp(r'file:///\S*?/(lib/\S+?\.dart:\d+)')
        .firstMatch(text)
        ?.group(1);
    final first = details.exceptionAsString().split('\n').first;
    _reported.add(place == null ? first : '$first [$place]');
  };
}

String? _exception(WidgetTester tester) {
  tester.takeException();
  if (_reported.isEmpty) return null;
  final unique = _reported.toSet().toList();
  _reported.clear();
  return unique.take(3).join('; ');
}

Future<void> _guideline(
  WidgetTester tester,
  List<String> failures,
  String where,
  String name,
  AccessibilityGuideline guideline,
) async {
  try {
    await expectLater(tester, meetsGuideline(guideline));
  } on TestFailure catch (e) {
    final reason = e.message?.split('\n').where((l) => l.trim().isNotEmpty);
    failures.add('$where, $name: ${reason?.take(4).join(' | ')}');
  }
}

/// Opens every screen and collects what is wrong with each.
Future<List<String>> _audit(
  WidgetTester tester,
  AppDatabase db, {
  required String variant,
  bool guidelines = true,
}) async {
  final failures = <String>[];
  final original = FlutterError.onError;
  _collectErrors();
  try {
    return await _auditScreens(tester, db, failures, variant, guidelines);
  } finally {
    // The test framework wants its own handler back before the test ends.
    FlutterError.onError = original;
  }
}

Future<List<String>> _auditScreens(
  WidgetTester tester,
  AppDatabase db,
  List<String> failures,
  String variant,
  bool guidelines,
) async {
  // Without the real font, text is much wider than on a phone.
  await tester.runAsync(loadRealFonts);
  await pumpAppWithDatabase(tester, db);
  _exception(tester);

  Future<void> check(String screen) async {
    final where = '$variant / $screen';
    final error = _exception(tester);
    if (error != null) failures.add('$where, layout: $error');
    if (guidelines) {
      await _guideline(
        tester,
        failures,
        where,
        'tap size',
        androidTapTargetGuideline,
      );
      await _guideline(
        tester,
        failures,
        where,
        'label',
        labeledTapTargetGuideline,
      );
    }
    _exception(tester);
  }

  for (final tab in _tabs) {
    await _openTab(tester, tab);
    await check(tab);
  }
  for (final title in _moreScreens) {
    await _openTab(tester, 'More');
    try {
      if (title == 'Help & guide') {
        await tester.tap(find.byKey(const ValueKey('more-help')));
        await tester.pumpAndSettle();
      } else {
        await tapMoreRow(tester, tr(title));
      }
    } on Object {
      failures.add('$variant / $title, could not be opened from More');
      continue;
    }
    // These screens open over the tabs, without the bottom bar.
    if (find.byType(NavigationBar).evaluate().isNotEmpty) {
      failures.add('$variant / $title, did not open (the tap missed the row)');
      continue;
    }
    await check(title);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }
  return failures;
}

void _phone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
}

void main() {
  void report(List<String> failures) {
    for (final f in failures) {
      // ignore: avoid_print
      print('AUDIT $f');
    }
    expect(failures, isEmpty);
  }

  testWithDatabase('every screen meets the accessibility guidelines (light)', (
    tester,
    db,
  ) async {
    _phone(tester);
    await _seed(db);
    report(await _audit(tester, db, variant: 'light'));
  }, seedDefaults: true);

  testWithDatabase('every screen meets the accessibility guidelines (dark)', (
    tester,
    db,
  ) async {
    _phone(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await _seed(db);
    report(await _audit(tester, db, variant: 'dark'));
  }, seedDefaults: true);

  testWithDatabase('every screen fits with large text (x1.5)', (
    tester,
    db,
  ) async {
    _phone(tester, textScale: 1.5);
    await _seed(db);
    report(await _audit(tester, db, variant: 'text x1.5', guidelines: false));
  }, seedDefaults: true);

  testWithDatabase('every screen fits in Bangla with larger text (x1.3)', (
    tester,
    db,
  ) async {
    _phone(tester, textScale: 1.3);
    await _seed(db);
    setAppLanguage(AppLanguage.bangla);
    report(await _audit(tester, db, variant: 'bangla', guidelines: false));
  }, seedDefaults: true);
}
