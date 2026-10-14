import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/app_info.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> openSettings(WidgetTester tester) =>
    openFromMore(tester, 'Settings');

Future<void> tapChip(WidgetTester tester, String key) async {
  final chip = find.byKey(ValueKey(key));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<AppPreferences> saved(AppDatabase db) => SettingsRepository(db).load();

MaterialApp materialApp(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

/// Starts the app the way `main()` does when [preferences] were saved: they
/// are in the database and are also what the first frame uses.
Future<void> pumpWithPreferences(
  WidgetTester tester,
  AppDatabase db,
  AppPreferences preferences,
) async {
  await SettingsRepository(db).save(preferences);
  await pumpAppWithDatabase(
    tester,
    db,
    overrides: [initialPreferencesProvider.overrideWithValue(preferences)],
  );
}

void main() {
  group('the screen', () {
    testWithDatabase('opens from More with its sections', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      expect(appBarTitle('Settings'), findsOneWidget);
      for (final title in [
        'Appearance',
        'New transactions',
        'Calendar',
        'About',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWithDatabase('starts on the defaults', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      bool selected(String key) =>
          tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;
      expect(selected('language-english'), isTrue);
      expect(selected('theme-system'), isTrue);
      expect(selected('amount-entry-keyboard'), isTrue);
      expect(selected('week-start-sunday'), isTrue);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('default-account-value')))
            .data,
        'The account used last',
      );
    });

    testWithDatabase('says which version of the app it is', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('app-version'))).data,
        'Version $appVersion',
      );
      expect(find.textContaining('works without the internet'), findsOneWidget);
    });
  });

  group('theme', () {
    testWithDatabase('follows the phone to start with', (tester, db) async {
      await pumpAppWithDatabase(tester, db);

      expect(materialApp(tester).themeMode, ThemeMode.system);
    });

    testWithDatabase('can be dark, then light, and is saved', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tapChip(tester, 'theme-dark');
      expect(materialApp(tester).themeMode, ThemeMode.dark);
      expect((await saved(db)).theme, ThemePreference.dark);

      await tapChip(tester, 'theme-light');
      expect(materialApp(tester).themeMode, ThemeMode.light);
      expect((await saved(db)).theme, ThemePreference.light);
    });

    testWithDatabase('starts as it was saved', (tester, db) async {
      await pumpWithPreferences(
        tester,
        db,
        const AppPreferences(theme: ThemePreference.dark),
      );

      expect(materialApp(tester).themeMode, ThemeMode.dark);
    });
  });

  group('language', () {
    Future<void> loadBangla(WidgetTester tester) =>
        tester.runAsync(() => initializeDateFormatting('bn'));

    testWithDatabase('switches the whole app to Bangla and back', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await loadBangla(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tapChip(tester, 'language-bangla');

      // The screen itself, and then the tabs behind it.
      expect(appBarTitle('সেটিংস'), findsOneWidget);
      expect(appBarTitle('Settings'), findsNothing);
      expect(isBangla, isTrue);
      expect(materialApp(tester).locale, const Locale('bn'));

      await tapChip(tester, 'language-english');

      expect(appBarTitle('Settings'), findsOneWidget);
      expect(isBangla, isFalse);
      expect(materialApp(tester).locale, const Locale('en'));
    });

    testWithDatabase('is saved', (tester, db) async {
      useTallScreen(tester);
      await loadBangla(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tapChip(tester, 'language-bangla');

      expect((await saved(db)).language, AppLanguage.bangla);
    });

    testWithDatabase('offers each language in its own script', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      expect(find.text('English'), findsOneWidget);
      expect(find.text('বাংলা'), findsOneWidget);
    });

    testWithDatabase('the first frame is already in Bangla when it was saved', (
      tester,
      db,
    ) async {
      await loadBangla(tester);
      await pumpWithPreferences(
        tester,
        db,
        const AppPreferences(language: AppLanguage.bangla),
      );

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('হোম'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
        findsNothing,
      );
    });

    testWithDatabase('writes the main screens in Bangla', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await loadBangla(tester);
      await pumpWithPreferences(
        tester,
        db,
        const AppPreferences(language: AppLanguage.bangla),
      );

      Finder tab(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      for (final (english, bangla) in [
        ('Transactions', 'লেনদেন'),
        ('Budget', 'বাজেট'),
        ('Reports', 'রিপোর্ট'),
        ('More', 'আরও'),
      ]) {
        expect(tab(bangla), findsOneWidget, reason: english);
      }

      await tester.tap(tab('আরও'));
      await tester.pumpAndSettle();
      await tester.tap(listRow('অ্যাকাউন্ট'));
      await tester.pumpAndSettle();
      expect(appBarTitle('অ্যাকাউন্ট'), findsOneWidget);
      // The total is written with Bengali digits.
      expect(find.byKey(const ValueKey('total-balance')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('total-balance'))).data,
        matches(RegExp(r'^৳[০-৯,.]+$')),
      );
    });

    testWithDatabase('error messages are in Bangla too', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await loadBangla(tester);
      await pumpWithPreferences(
        tester,
        db,
        const AppPreferences(language: AppLanguage.bangla),
      );
      await openAddForm(tester);

      await tester.tap(find.text('সংরক্ষণ করুন'));
      await tester.pumpAndSettle();

      expect(find.text('টাকার অঙ্ক দিন।'), findsOneWidget);
    });
  });

  group('the account to start with', () {
    testWithDatabase('is the one used last until one is chosen', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 100,
        accountId: b.bkash,
        categoryId: b.food,
        date: DateTime(2026, 10, 5),
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-field')),
          matching: find.text('bKash'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('can be chosen, and new transactions start with it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 100,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 5),
      );
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('default-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('default-account-${b.bkash}')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('default-account-value')))
            .data,
        'bKash',
      );
      expect((await saved(db)).defaultAccountId, b.bkash);

      // Back to Home, and a new transaction: bKash, not the last used Cash.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-field')),
          matching: find.text('bKash'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('can go back to the one used last', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await SettingsRepository(db)
          .save(AppPreferences(defaultAccountId: b.bkash));
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('default-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('default-account-last-used')));
      await tester.pumpAndSettle();

      expect((await saved(db)).defaultAccountId, isNull);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('default-account-value')))
            .data,
        'The account used last',
      );
    });

    testWithDatabase('lists active accounts only, with the choice marked', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await db.accountsDao.setArchived(b.bkash, archived: true);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('default-account')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('default-account-${b.cash}')), findsOneWidget);
      expect(find.byKey(ValueKey('default-account-${b.bkash}')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('default-account-last-used')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
    });
  });

  group('typing the amount', () {
    testWithDatabase('can start with the calculator', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);
      await tapChip(tester, 'amount-entry-calculator');
      expect((await saved(db)).amountEntry, AmountEntry.calculator);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await openAddForm(tester);

      expect(find.byType(AmountKeypad), findsOneWidget);
      // No system keyboard is asked for.
      expect(
        tester.widget<TextField>(amountField).focusNode!.hasFocus,
        isFalse,
      );
    });

    testWithDatabase('starts with the keyboard by default', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(find.byType(AmountKeypad), findsNothing);
      expect(tester.widget<TextField>(amountField).focusNode!.hasFocus, isTrue);
    });

    testWithDatabase('can still switch to the keyboard from the calculator', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await SettingsRepository(db)
          .save(const AppPreferences(amountEntry: AmountEntry.calculator));
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      expect(find.byType(AmountKeypad), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calculator-toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(AmountKeypad), findsNothing);
    });
  });

  group('Fun mode', () {
    testWithDatabase('is on, and can be turned off and on again', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);
      Finder fun() => find.byKey(const ValueKey('fun-mode'));

      expect(tester.widget<SwitchListTile>(fun()).value, isTrue);

      await tester.ensureVisible(fun());
      await tester.tap(fun());
      await tester.pumpAndSettle();
      expect((await saved(db)).funMode, isFalse);
      expect(tester.widget<SwitchListTile>(fun()).value, isFalse);

      await tester.tap(fun());
      await tester.pumpAndSettle();
      expect((await saved(db)).funMode, isTrue);
    });
  });

  group('the week', () {
    testWithDatabase('can start on Saturday or Monday, and is saved', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tapChip(tester, 'week-start-monday');
      expect((await saved(db)).weekStart, WeekStart.monday);

      await tapChip(tester, 'week-start-saturday');
      expect((await saved(db)).weekStart, WeekStart.saturday);
    });

    testWithDatabase('changes what "this week" shows on Home', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      // Sunday 11 October is "now". Monday 12 is not in the week that has
      // Sunday as its first day, but 9 and 10 October are in a Monday week.
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 10000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 9, 12),
      );
      await pumpAppWithDatabase(tester, db);

      Finder weekTile() => find.byKey(const ValueKey('spent-week'));
      expect(
        find.descendant(of: weekTile(), matching: find.text('৳0.00')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(listRow('Settings'));
      await tester.pumpAndSettle();
      await tapChip(tester, 'week-start-monday');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: weekTile(), matching: find.text('৳100.00')),
        findsOneWidget,
      );
    });
  });
}
