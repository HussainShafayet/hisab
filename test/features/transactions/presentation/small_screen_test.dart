import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/fonts.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// A small phone, 360 x 640 logical pixels.
void useSmallPhone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
}

void main() {
  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the add form fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await insertTestAccount(db, name: 'Cash');
      await insertTestAccount(db, name: 'bKash');
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Overflows are reported as exceptions, which fail the test.
      expect(tester.takeException(), isNull);
      final screen = tester.view.physicalSize;
      for (final label in ['Save', 'Save & new']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: label);
        expect(rect.right, lessThanOrEqualTo(screen.width), reason: label);
      }

      // With the calculator on, its keypad is fully visible too.
      await turnCalculatorOn(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const ValueKey('key-+'))).bottom,
        lessThanOrEqualTo(screen.height),
      );
      for (final label in ['Save', 'Save & new']) {
        expect(
          tester.getRect(find.text(label)).bottom,
          lessThanOrEqualTo(screen.height),
          reason: label,
        );
      }
    }, seedDefaults: true);
  }

  testWithDatabase('a full add flow works on a small phone', (
    tester,
    db,
  ) async {
    useSmallPhone(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await typeAmount(tester, '250');
    await chooseCategory(tester, b.food);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rows = await db.transactionsDao.getBetween(
      DateTime(2000),
      DateTime(2100),
    );
    expect(rows.single.amount, 25000);
  });

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the transaction list fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 5000000000,
        accountId: b.cash,
        categoryId: b.salary,
        date: DateTime(2026, 10, 11, 9),
        note: 'A very long note about the salary that must not break the row',
      );
      await addTransaction(
        db,
        type: TransactionType.transfer,
        amount: 123456789,
        accountId: b.cash,
        toAccountId: b.bkash,
        date: DateTime(2026, 10, 10, 9),
      );
      await pumpAppWithDatabase(tester, db);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('+৳5,00,00,000.00'), findsWidgets);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the accounts list fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'A savings account with a rather long name',
          type: AccountType.bank,
          openingBalance: const Value(-5000000000),
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(tester.takeException(), isNull);
      expect(find.text('-৳5,00,00,000.00'), findsWidgets);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase(
      'the accounts screen with every kind of account fits (text x$scale)',
      (tester, db) async {
        useSmallPhone(tester, textScale: scale);
        for (final type in AccountType.values) {
          await db.accountsDao.insertAccount(
            AccountsCompanion.insert(
              name: 'A long name for the ${type.name} account',
              type: type,
              openingBalance: const Value(123456789012),
            ),
          );
        }
        await pumpAppWithDatabase(tester, db);
        await openFromMore(tester, 'Accounts');

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('total-card')), findsOneWidget);
        // Every kind has its line in the breakdown.
        for (final type in AccountType.values) {
          expect(
            find.byKey(ValueKey('type-total-${type.name}')),
            findsOneWidget,
          );
        }
      },
    );

    testWithDatabase('the account form fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'A savings account with a rather long name indeed',
      );
      // The balance is below the preview and the kind tiles.
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Opening balance'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance'),
        '99999999999.99',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The button stays on screen, below the form.
      expect(
        tester.getRect(find.widgetWithText(FilledButton, 'Add account')).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
    });

    testWithDatabase('the category form fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'A category with a name that is far too long for one line of text',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(find.widgetWithText(FilledButton, 'Add category'))
            .bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
    });

    testWithDatabase('the category tree with long names fits (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      var parent = await insertTestCategory(
        db,
        name: 'A top level category with a very long name',
      );
      for (var level = 2; level <= 5; level++) {
        parent = await insertTestCategory(
          db,
          name: 'Level $level of a category with a long name',
          parentId: parent,
        );
      }
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');

      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase(
      'the main screens fit a small phone in Bangla (text x$scale)',
      (tester, db) async {
        useSmallPhone(tester, textScale: scale);
        final b = await seedBasics(db);
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 123456789,
          accountId: b.cash,
          categoryId: b.food,
          date: DateTime(2026, 10, 11, 9),
          note: 'A long note that has to fit on a small phone',
        );
        const bangla = AppPreferences(language: AppLanguage.bangla);
        await tester.runAsync(() => initializeDateFormatting('bn'));
        await SettingsRepository(db).save(bangla);
        await pumpAppWithDatabase(
          tester,
          db,
          overrides: [initialPreferencesProvider.overrideWithValue(bangla)],
        );
        expect(tester.takeException(), isNull);

        Finder tab(String label) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );
        // Home, Transactions, Budget, Reports and More, in Bangla.
        for (final label in ['হোম', 'লেনদেন', 'বাজেট', 'রিপোর্ট', 'আরও']) {
          await tester.tap(tab(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }

        // The screens behind More.
        for (final title in [
          'অ্যাকাউন্ট',
          'ক্যাটাগরি',
          'ব্যাকআপ ও এক্সপোর্ট',
          'সেটিংস',
        ]) {
          await tapMoreRow(tester, title);
          expect(tester.takeException(), isNull, reason: title);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }

        // The form for a new transaction.
        await tester.tap(tab('হোম'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the loan screens fit a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      final cash = await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'A cash account with a rather long name',
          type: AccountType.cash,
          openingBalance: const Value(123456789012),
        ),
      );
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'A credit card with a very long name for its bank',
          type: AccountType.creditCard,
          openingBalance: const Value(-98765432100),
          creditLimit: const Value(123456789012),
          billDueDay: const Value(31),
        ),
      );
      final repo = DebtsRepository(db);
      final id = await repo.createDebt(
        person: 'A person with a rather long name indeed, Mr Rahim Uddin',
        direction: DebtDirection.lent,
        amount: 99999999999,
        openedOn: DateTime(2026, 9, 1),
        dueOn: DateTime(2026, 10, 1),
        note: 'A long note about why this money was lent to this person',
        accountId: cash,
      );
      await repo.addPayment(id, amount: 12345678, paidOn: DateTime(2026, 9, 5));
      await repo.createDebt(
        person: 'A person with a rather long name indeed, Mr Rahim Uddin',
        direction: DebtDirection.borrowed,
        amount: 5000,
        openedOn: DateTime(2026, 10, 1),
      );
      await pumpAppWithDatabase(tester, db);
      expect(tester.takeException(), isNull);

      // Home has the Loans card, below the first screenful.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('loans-home-card')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('loans-home-card')), findsOneWidget);

      await openFromMore(tester, 'Loans');
      expect(tester.takeException(), isNull);

      // The money I will give has the credit card at the top.
      await tester.tap(find.byKey(const ValueKey('tab-give')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // And the people, then one person with everything.
      await tester.tap(find.byKey(const ValueKey('tab-people')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(
          ValueKey(
            'person-tile-${'A person with a rather long name indeed, Mr Rahim Uddin'.toLowerCase()}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('set-off')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('set-off')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-get')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(ValueKey('debt-$id')));
      await tester.pumpAndSettle();
      // Up out of the way of the add button.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('debt-$id')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The payment dialog has the account as a card.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-payment')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-payment')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The account card and the extra details fit too.
      await tester.ensureVisible(
        find.byKey(const ValueKey('loan-account-switch')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('loan-account-switch')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('More details'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The button stays on screen below the form.
      expect(
        tester.getRect(find.widgetWithText(FilledButton, 'Add loan')).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
    });

    testWithDatabase(
      'the credit card form and the pay bill form fit (text x$scale)',
      (tester, db) async {
        useSmallPhone(tester, textScale: scale);
        final card = await db.accountsDao.insertAccount(
          AccountsCompanion.insert(
            name: 'A credit card with a very long name for its bank',
            type: AccountType.creditCard,
            openingBalance: const Value(-98765432100),
            creditLimit: const Value(123456789012),
            billDueDay: const Value(31),
          ),
        );
        await db.accountsDao.insertAccount(
          AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
        );
        await pumpAppWithDatabase(tester, db);

        await openFromMore(tester, 'Accounts');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(ValueKey('balance-$card')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('credit-limit')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(const ValueKey('credit-limit')), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await openFromMore(tester, 'Loans');
        await tester.tap(find.byKey(const ValueKey('tab-give')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('pay-bill-$card')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('layout on a 360 dp wide phone', () {
    testWithDatabase('bottom bar labels stay on one line', (tester, db) async {
      useSmallPhone(tester);
      await tester.runAsync(loadRealFonts);
      await pumpAppWithDatabase(tester, db);

      for (final label in [
        'Home',
        'Transactions',
        'Budget',
        'Reports',
        'More',
      ]) {
        final size = tester.getSize(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        expect(size.height, lessThan(18), reason: '$label wraps');
      }
    });

    testWithDatabase('the filter sheet is not covered by the add button', (
      tester,
      db,
    ) async {
      useSmallPhone(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();

      // A tap that lands on something else, like the add button, fails.
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Filter'), findsNothing);
    });

    testWithDatabase('day totals sit at the right edge', (tester, db) async {
      useSmallPhone(tester);
      await tester.runAsync(loadRealFonts);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 41000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 11, 12),
      );
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      final total = find.descendant(
        of: find.byType(DayHeader),
        matching: find.text('-৳410.00'),
      );
      expect(tester.getRect(total).right, closeTo(360 - 16, 1));
    });

    testWithDatabase('the save buttons stay on one line', (tester, db) async {
      useSmallPhone(tester);
      await tester.runAsync(loadRealFonts);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      for (final label in ['Save', 'Save & new']) {
        expect(
          tester.getSize(find.text(label)).height,
          lessThan(24),
          reason: label,
        );
      }
    });

    for (final scale in [1.0, 1.5]) {
      testWithDatabase(
        'the category picker fits a small phone (text x$scale)',
        (tester, db) async {
          useSmallPhone(tester, textScale: scale);
          await tester.runAsync(loadRealFonts);
          await insertTestAccount(db, name: 'Cash');
          final food = await insertTestCategory(
            db,
            name: 'Food and everything we eat or drink at home and outside',
          );
          final shopping = await insertTestCategory(db, name: 'Shopping');
          final groceries = await insertTestCategory(
            db,
            name: 'Groceries from the neighbourhood bazaar',
            parentId: food,
          );
          await insertTestCategory(
            db,
            name: 'Rice, lentils and oil in bulk for the whole month',
            parentId: groceries,
          );
          await insertTestCategory(db, name: 'Other', parentId: food);
          await insertTestCategory(db, name: 'Other', parentId: shopping);
          await pumpAppWithDatabase(tester, db);
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('category-field')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Open the long ones.
          await tester.tap(find.byKey(ValueKey('category-expand-$food')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('category-expand-$groceries')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Two categories are called "Other": a search says where each is.
          await tester.enterText(
            find.byKey(const ValueKey('category-search')),
            'other',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Other'), findsNWidgets(2));
        },
      );
    }
  });

  group('on a short window (phone turned sideways, split screen)', () {
    void useShortWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWithDatabase('the add form scrolls instead of overflowing', (
      tester,
      db,
    ) async {
      useShortWindow(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // An overflow is reported as an exception.
      expect(tester.takeException(), isNull);
    });

    testWithDatabase('a transaction can be saved from start to finish', (
      tester,
      db,
    ) async {
      useShortWindow(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      // The keypad sits at the end of the long list here: type on the keyboard.
      await turnKeyboardOn(tester);

      // The form is one long list here, so scroll to each part like a user.
      // The Note text field has a Scrollable of its own: take the outer one.
      final formList = find.byType(Scrollable).first;
      await typeAmount(tester, '75');
      await tester.ensureVisible(find.byKey(const ValueKey('category-field')));
      await chooseCategory(tester, b.food);
      await tester.scrollUntilVisible(
        find.text('Save'),
        100,
        scrollable: formList,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final rows = await db.transactionsDao.getBetween(
        DateTime(2000),
        DateTime(2100),
      );
      expect(rows.single.amount, 7500);
    });

    testWithDatabase('the calculator keypad scrolls with the form', (
      tester,
      db,
    ) async {
      useShortWindow(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // A new transaction starts with the keypad, at the end of the list.
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('key-+')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWithDatabase('the transfer form fits too', (tester, db) async {
      useShortWindow(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Transfer'));
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('the budget screen fits a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await tester.runAsync(loadRealFonts);
      final b = await seedBasics(db);
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(month: '2026-10', amount: 5000000000),
      );
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          amount: 100,
          categoryId: Value(b.food),
        ),
      );
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 123456789,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      await pumpAppWithDatabase(tester, db);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Budget'),
        ),
      );
      await tester.pumpAndSettle();

      // An overflow or a ListTile layout failure is reported as an exception.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('overall-budget')), findsOneWidget);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase('Home and Reports fit a small phone (text x$scale)', (
      tester,
      db,
    ) async {
      useSmallPhone(tester, textScale: scale);
      await tester.runAsync(loadRealFonts);
      final b = await seedBasics(db);
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(month: '2026-10', amount: 5000000000),
      );
      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 5000000000,
        accountId: b.cash,
        categoryId: b.salary,
        date: DateTime(2026, 10, 1),
        note: 'A very long note about the salary that must not break a row',
      );
      for (final category in [b.food, b.transport]) {
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 123456789,
          accountId: b.cash,
          categoryId: category,
          date: DateTime(2026, 10, 11, 9),
        );
      }
      await pumpAppWithDatabase(tester, db);

      // Home is the first tab.
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('budget-ring')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('budget-ring')), findsOneWidget);
      // Scroll to the bottom of Home, where the recent transactions are.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Reports'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 1.5]) {
    testWithDatabase(
      'Backup and the CSV import fit a small phone (text x$scale)',
      (tester, db) async {
        useSmallPhone(tester, textScale: scale);
        await tester.runAsync(loadRealFonts);
        await seedBasics(db);
        final gateway = FakeFileGateway()
          ..pickText(
            'a-sheet-with-a-rather-long-file-name-for-the-month-of-october.csv',
            'Transaction date,A very long description column name,Category,Total amount (BDT),Paid from\n'
                '11/10/2026,বাজার করলাম অনেক কিছু একসাথে,Food,"-৳50,00,00,000.50",bKash personal wallet\n'
                '12/10/2026,Rent for the whole month of October,Rent,-12000,Cash\n'
                'not a date,Broken,Food,-5,Cash\n',
          );
        await pumpAppWithDatabase(
          tester,
          db,
          overrides: [fileGatewayProvider.overrideWithValue(gateway)],
        );

        await openFromMore(tester, 'Backup & export');
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('import-csv')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Choose CSV file'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The map step is a long list: look at the end of it too.
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
