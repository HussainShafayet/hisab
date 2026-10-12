import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

// "Now" in widget tests is Sunday 11 October 2026.
Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

class Setup {
  Setup(this.cash, this.rent, this.salary);
  final int cash;
  final int rent;
  final int salary;
}

Future<Setup> seed(AppDatabase db) async => Setup(
  await insertTestAccount(db, name: 'Cash'),
  await insertTestCategory(db, name: 'Rent'),
  await insertTestCategory(db, name: 'Salary', type: CategoryType.income),
);

Future<int> makeRule(
  AppDatabase db,
  Setup s, {
  String title = 'House rent',
  DateTime? start,
  bool auto = false,
  bool remind = true,
  int amount = 1500000,
}) => RecurringRepository(db).createRule(
  title: title,
  type: TransactionType.expense,
  amount: amount,
  accountId: s.cash,
  categoryId: s.rent,
  frequency: RecurrenceFrequency.monthly,
  startDate: start ?? DateTime(2026, 10, 5),
  autoAdd: auto,
  remind: remind,
);

Future<void> openRecurring(WidgetTester tester) =>
    openFromMore(tester, 'Recurring');

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<List<TransactionRow>> transactions(AppDatabase db) =>
    db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

void main() {
  group('the list', () {
    testWithDatabase('opens from More, with an empty state to start', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);

      expect(appBarTitle('Recurring'), findsOneWidget);
      expect(find.text('Nothing repeats yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add recurring'));
      await tester.pumpAndSettle();
      expect(appBarTitle('New recurring'), findsOneWidget);
    });

    testWithDatabase('shows each rule with how often and when it is next', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      final later = await makeRule(db, s, start: DateTime(2026, 11, 5));
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);

      expect(
        find.descendant(
          of: find.byKey(ValueKey('rule-$later')),
          matching: find.text('Every month · Next 5 Nov'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('rule-$later')),
          matching: find.text('৳15,000.00'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('says when a rule adds itself, is paused or has ended', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      final auto = await makeRule(
        db,
        s,
        title: 'Salary day',
        start: DateTime(2026, 11, 5),
        auto: true,
      );
      final paused = await makeRule(
        db,
        s,
        title: 'Paused one',
        start: DateTime(2026, 11, 5),
      );
      await RecurringRepository(db).setPaused(paused, paused: true);
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);

      expect(
        find.text('Every month · Next 5 Nov · Adds itself'),
        findsOneWidget,
      );
      expect(find.text('Every month · Paused'), findsOneWidget);
      expect(auto, isNot(paused));
    });

    testWithDatabase('can be paused and resumed from the menu', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      final id = await makeRule(db, s, start: DateTime(2026, 11, 5));
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);

      await tapKey(tester, 'menu-$id');
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect((await RecurringRepository(db).getRule(id))!.isPaused, isTrue);

      await tapKey(tester, 'menu-$id');
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect((await RecurringRepository(db).getRule(id))!.isPaused, isFalse);
    });

    testWithDatabase('can be deleted after asking', (tester, db) async {
      useTallScreen(tester);
      final s = await seed(db);
      final id = await makeRule(db, s, start: DateTime(2026, 11, 5));
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);

      await tapKey(tester, 'menu-$id');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "House rent"?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await RecurringRepository(db).getRule(id), isNotNull);

      await tapKey(tester, 'menu-$id');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await RecurringRepository(db).getRule(id), isNull);
      expect(find.text('Nothing repeats yet'), findsOneWidget);
    });
  });

  group('the form', () {
    testWithDatabase('makes a rule', (tester, db) async {
      useTallScreen(tester);
      final s = await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'House rent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '15000',
      );
      await tapKey(tester, 'recurring-category');
      await tester.tap(find.byKey(ValueKey('category-option-${s.rent}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('recurring-category-value')),
            )
            .data,
        'Rent',
      );
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add recurring'));
      await tester.pumpAndSettle();

      final rule = (await RecurringRepository(db).getRules()).single;
      expect(rule.title, 'House rent');
      expect(rule.amount, 1500000);
      expect(rule.accountId, s.cash);
      expect(rule.categoryId, s.rent);
      expect(rule.frequency, RecurrenceFrequency.monthly);
      expect(rule.startDate, DateTime(2026, 10, 11));
      expect(find.text('House rent'), findsOneWidget);
    });

    testWithDatabase('asks for a name, an amount, an account and a category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add recurring'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Rent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '100',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add recurring'));
      await tester.pumpAndSettle();
      expect(find.text('Choose an account.'), findsOneWidget);
    });

    testWithDatabase('changing the type forgets the category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tapKey(tester, 'recurring-category');
      await tester.tap(find.byKey(ValueKey('category-option-${s.rent}')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('recurring-category-value')),
            )
            .data,
        'Choose a category',
      );
    });

    testWithDatabase('adding by itself hides the reminder switch', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('remind')), findsOneWidget);

      await tapKey(tester, 'auto-add');

      expect(find.byKey(const ValueKey('remind')), findsNothing);
    });

    testWithDatabase(
      'asks to allow notifications when reminders are switched on',
      (tester, db) async {
        useTallScreen(tester);
        await seed(db);
        final scheduler = FakeReminderScheduler()..allowed = false;
        await pumpAppWithDatabase(
          tester,
          db,
          overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
        );
        await openRecurring(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // On to start with: off, then on again.
        await tapKey(tester, 'remind');
        expect(scheduler.permissionRequests, 0);
        await tapKey(tester, 'remind');

        expect(scheduler.permissionRequests, 1);
        expect(
          find.textContaining('Notifications are off for Hishab'),
          findsOneWidget,
        );
      },
    );

    testWithDatabase('edits a rule', (tester, db) async {
      useTallScreen(tester);
      final s = await seed(db);
      final id = await makeRule(db, s, start: DateTime(2026, 11, 5));
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);

      await tester.tap(find.byKey(ValueKey('rule-$id')));
      await tester.pumpAndSettle();
      expect(appBarTitle('Edit recurring'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Name'))
            .controller!
            .text,
        'House rent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '16000',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect((await RecurringRepository(db).getRule(id))!.amount, 1600000);
    });
  });

  group('what is due', () {
    testWithDatabase('shows on Home, and Add makes the transaction', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      final id = await makeRule(db, s);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('due-recurring')), findsOneWidget);
      expect(find.text('Due now'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey('due-text-$id'))).data,
        'Due on 5 Oct',
      );

      await tapKey(tester, 'add-due-$id');

      expect(find.text('Added House rent.'), findsOneWidget);
      final row = (await transactions(db)).single;
      expect(row.amount, 1500000);
      expect(row.note, 'House rent');
      // The next one is in November, so nothing is waiting any more.
      expect(find.byKey(const ValueKey('due-recurring')), findsNothing);
    });

    testWithDatabase('Skip moves on without a transaction', (tester, db) async {
      useTallScreen(tester);
      final s = await seed(db);
      final id = await makeRule(db, s);
      await pumpAppWithDatabase(tester, db);

      await tapKey(tester, 'skip-$id');

      expect(find.text('Skipped House rent.'), findsOneWidget);
      expect(await transactions(db), isEmpty);
      expect(find.byKey(const ValueKey('due-recurring')), findsNothing);
    });

    testWithDatabase('says how many more days are waiting', (tester, db) async {
      useTallScreen(tester);
      final s = await seed(db);
      final id = await makeRule(db, s, start: DateTime(2026, 8, 5));
      await pumpAppWithDatabase(tester, db);

      expect(
        tester.widget<Text>(find.byKey(ValueKey('due-text-$id'))).data,
        'Due on 5 Aug, and 2 more',
      );

      await tapKey(tester, 'add-due-$id');

      expect(
        tester.widget<Text>(find.byKey(ValueKey('due-text-$id'))).data,
        'Due on 5 Sep, and 1 more',
      );
    });

    testWithDatabase('is not shown when nothing is due or the rule is paused', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      await makeRule(db, s, start: DateTime(2026, 11, 5));
      final paused = await makeRule(db, s, title: 'Paused');
      await RecurringRepository(db).setPaused(paused, paused: true);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('due-recurring')), findsNothing);
    });

    testWithDatabase('also shows at the top of the Recurring screen', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      await makeRule(db, s);
      await pumpAppWithDatabase(tester, db);
      await openRecurring(tester);

      expect(find.byKey(const ValueKey('due-recurring')), findsOneWidget);
    });

    testWithDatabase(
      'rules that add themselves are added when the app starts',
      (tester, db) async {
        useTallScreen(tester);
        final s = await seed(db);
        await makeRule(db, s, start: DateTime(2026, 8, 5), auto: true);

        await pumpAppWithDatabase(tester, db);

        expect(await transactions(db), hasLength(3));
        expect(find.byKey(const ValueKey('due-recurring')), findsNothing);
      },
    );
  });

  group('reminders', () {
    testWithDatabase('are scheduled for the next days of a rule that asks', (
      tester,
      db,
    ) async {
      final s = await seed(db);
      final id = await makeRule(db, s, start: DateTime(2026, 10, 15));
      final scheduler = FakeReminderScheduler();

      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      );

      expect(scheduler.scheduled.map((r) => r.when), [
        DateTime(2026, 10, 15, 9),
        DateTime(2026, 11, 15, 9),
        DateTime(2026, 12, 15, 9),
      ]);
      final first = scheduler.scheduled.first;
      expect(first.id, id * 10);
      expect(first.title, 'House rent');
      expect(first.body, '৳15,000.00 is due today.');
    });

    testWithDatabase('say "expected" for an income', (tester, db) async {
      final s = await seed(db);
      await RecurringRepository(db).createRule(
        title: 'Salary',
        type: TransactionType.income,
        amount: 5000000,
        accountId: s.cash,
        categoryId: s.salary,
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 10, 25),
      );
      final scheduler = FakeReminderScheduler();

      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      );

      expect(scheduler.scheduled.first.body, '৳50,000.00 is expected today.');
    });

    testWithDatabase(
      'are not scheduled for rules that do not ask or add themselves',
      (tester, db) async {
        final s = await seed(db);
        await makeRule(
          db,
          s,
          title: 'Quiet',
          start: DateTime(2026, 10, 15),
          remind: false,
        );
        await makeRule(
          db,
          s,
          title: 'Auto',
          start: DateTime(2026, 10, 15),
          auto: true,
        );
        final scheduler = FakeReminderScheduler();

        await pumpAppWithDatabase(
          tester,
          db,
          overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
        );

        expect(scheduler.scheduled, isEmpty);
      },
    );

    testWithDatabase('are set up again when a rule is added', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seed(db);
      final scheduler = FakeReminderScheduler();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      );
      expect(scheduler.scheduled, isEmpty);

      await makeRule(db, s, start: DateTime(2026, 10, 20));
      await tester.pumpAndSettle();

      expect(scheduler.scheduled, isNotEmpty);
    });
  });
}
