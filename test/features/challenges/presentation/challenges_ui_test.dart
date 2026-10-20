import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/challenges/data/challenges_repository.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> openChallenges(WidgetTester tester) =>
    openFromMore(tester, 'Challenges');

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String titleField(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const ValueKey('challenge-title')))
    .controller!
    .text;

Future<void> chooseCategory(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.byKey(const ValueKey('challenge-category')));
  await tester.tap(find.byKey(const ValueKey('challenge-category')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

DateTime day(int d, {int month = 10}) => DateTime(2026, month, d);

void main() {
  group('the challenges screen', () {
    testWithDatabase('opens from More and starts empty', (tester, db) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await openChallenges(tester);

      expect(appBarTitle('Challenges'), findsOneWidget);
      expect(find.text('No challenges yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-challenge')), findsOneWidget);
    });

    testWithDatabase('lists the running, the coming and the finished', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final repo = ChallengesRepository(db);
      // Running: 9 to 15 October, day 3 of 7.
      await repo.create(
        title: 'No snacks',
        kind: ChallengeKind.noSpend,
        startDate: day(9),
        endDate: day(15),
      );
      // Coming: starts on the 14th.
      await repo.create(
        title: 'Cheap week',
        kind: ChallengeKind.limit,
        startDate: day(14),
        endDate: day(20),
        limit: 100000,
      );
      // Won: over, nothing spent.
      await repo.create(
        title: 'Old win',
        kind: ChallengeKind.noSpend,
        startDate: day(1),
        endDate: day(5),
      );
      // Broken: spent 300 against a limit of 200.
      await repo.create(
        title: 'Tight week',
        kind: ChallengeKind.limit,
        startDate: day(6),
        endDate: day(12),
        limit: 20000,
      );
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 30000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 7, 12),
      );
      await pumpAppWithDatabase(tester, db);

      await openChallenges(tester);

      expect(find.text('Running now'), findsOneWidget);
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
      String status(String title) {
        final id = [
          'No snacks',
          'Cheap week',
          'Old win',
          'Tight week',
        ].indexOf(title);
        return tester
            .widget<Text>(find.byKey(ValueKey('challenge-status-${id + 1}')))
            .data!;
      }

      // The first challenge made has id 1, and so on.
      expect(status('No snacks'), 'Day 3 of 7 · 5 days to go');
      expect(status('Cheap week'), 'Starts in 3 days');
      expect(status('Old win'), 'Completed: nothing spent!');
      expect(status('Tight week'), '৳100.00 over the limit');
    });

    testWithDatabase('deletes a challenge only after asking', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      final id = await ChallengesRepository(db).create(
        title: 'No snacks',
        kind: ChallengeKind.noSpend,
        startDate: day(9),
        endDate: day(15),
      );
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);

      await tapKey(tester, 'challenge-menu-$id');
      await tapKey(tester, 'challenge-delete');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('No snacks'), findsOneWidget);

      await tapKey(tester, 'challenge-menu-$id');
      await tapKey(tester, 'challenge-delete');
      await tapKey(tester, 'confirm-delete-challenge');

      expect(find.text('No snacks'), findsNothing);
      expect(find.text('No challenges yet'), findsOneWidget);
      expect(await db.challengesDao.getAll(), isEmpty);
    });
  });

  group('the challenge form', () {
    testWithDatabase('starts a no-spend challenge with a name made for you', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await insertTestCategory(db, name: 'Rickshaw');
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);
      await tapKey(tester, 'new-challenge');

      expect(titleField(tester), 'No spending for 7 days');
      expect(find.byKey(const ValueKey('challenge-limit')), findsNothing);

      await chooseCategory(tester, 'Rickshaw');
      expect(titleField(tester), 'No Rickshaw spending for 7 days');

      await tapKey(tester, 'length-14');
      expect(titleField(tester), 'No Rickshaw spending for 14 days');

      await tapKey(tester, 'challenge-save');

      final row = (await db.challengesDao.getAll()).single;
      expect(row.title, 'No Rickshaw spending for 14 days');
      expect(row.kind, ChallengeKind.noSpend);
      expect(row.limitAmount, 0);
      expect(row.categoryId, isNotNull);
      expect(row.startDate, day(11));
      expect(row.endDate, day(24));
      // Back on the list, with the new challenge on it.
      expect(appBarTitle('Challenges'), findsOneWidget);
      expect(find.text('No Rickshaw spending for 14 days'), findsOneWidget);
    });

    testWithDatabase('starts a challenge with a limit', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);
      await tapKey(tester, 'new-challenge');

      await tester.tap(find.byKey(const ValueKey('kind-limit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('challenge-limit')), findsOneWidget);

      // The limit is needed.
      await tapKey(tester, 'challenge-save');
      expect(await db.challengesDao.getAll(), isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('challenge-limit')),
        '2000',
      );
      await tester.pumpAndSettle();
      expect(titleField(tester), 'Spend under ৳2,000.00 in 7 days');
      await tapKey(tester, 'challenge-save');

      final row = (await db.challengesDao.getAll()).single;
      expect(row.kind, ChallengeKind.limit);
      expect(row.limitAmount, 200000);
    });

    testWithDatabase('a name the person wrote is not replaced', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);
      await tapKey(tester, 'new-challenge');

      await tester.enterText(
        find.byKey(const ValueKey('challenge-title')),
        'My dare',
      );
      await tapKey(tester, 'length-3');

      expect(titleField(tester), 'My dare');
    });

    testWithDatabase('editing starts from what was saved', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      final id = await ChallengesRepository(db).create(
        title: 'Cheap week',
        kind: ChallengeKind.limit,
        startDate: day(14),
        endDate: day(20),
        limit: 150000,
      );
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);

      await tapKey(tester, 'challenge-menu-$id');
      await tapKey(tester, 'challenge-edit');

      expect(titleField(tester), 'Cheap week');
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: find.byKey(const ValueKey('challenge-limit')),
                matching: find.byType(TextFormField),
              ),
            )
            .controller!
            .text,
        '1500',
      );
      await tester.enterText(
        find.byKey(const ValueKey('challenge-title')),
        'Cheaper week',
      );
      await tapKey(tester, 'challenge-save');

      expect((await db.challengesDao.getById(id))!.title, 'Cheaper week');
    });
  });

  group('presets and repeating', () {
    testWithDatabase('a preset fills the form and can be saved as it is', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await insertTestCategory(db, name: 'Rickshaw');
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);
      await tapKey(tester, 'new-challenge');

      await tapKey(tester, 'preset-rickshawWeek');
      expect(titleField(tester), 'No Rickshaw spending for 7 days');

      // The weekend: Friday 16 and Saturday 17 October, about all spending.
      await tapKey(tester, 'preset-weekend');
      expect(titleField(tester), 'No spending for 2 days');
      await tapKey(tester, 'challenge-save');

      final row = (await db.challengesDao.getAll()).single;
      expect(row.kind, ChallengeKind.noSpend);
      expect(row.categoryId, isNull);
      expect(row.startDate, day(16));
      expect(row.endDate, day(17));
    });

    testWithDatabase('the rickshaw preset needs a Rickshaw category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);
      await tapKey(tester, 'new-challenge');

      expect(find.byKey(const ValueKey('preset-day')), findsOneWidget);
      expect(find.byKey(const ValueKey('preset-week')), findsOneWidget);
      expect(find.byKey(const ValueKey('preset-rickshawWeek')), findsNothing);
    });

    testWithDatabase('presets are not offered when changing a challenge', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      final id = await ChallengesRepository(db).create(
        title: 'No snacks',
        kind: ChallengeKind.noSpend,
        startDate: day(9),
        endDate: day(15),
      );
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);

      await tapKey(tester, 'challenge-menu-$id');
      await tapKey(tester, 'challenge-edit');

      expect(find.byKey(const ValueKey('preset-day')), findsNothing);
    });

    testWithDatabase('the switch makes it start again, and it is shown', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openChallenges(tester);
      await tapKey(tester, 'new-challenge');
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('challenge-repeats')),
            )
            .value,
        isFalse,
      );

      await tapKey(tester, 'challenge-repeats');
      await tapKey(tester, 'challenge-save');

      expect((await db.challengesDao.getAll()).single.repeats, isTrue);
      expect(find.textContaining('Repeats'), findsOneWidget);
    });

    testWithDatabase('a challenge that ended starts again when the app opens', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await ChallengesRepository(db).create(
        title: 'Every week',
        kind: ChallengeKind.noSpend,
        startDate: day(1),
        endDate: day(7),
        repeats: true,
      );

      await pumpAppWithDatabase(tester, db);

      // Sunday 11 October is in the round 8 to 14 October.
      final rows = await db.challengesDao.getAll();
      expect(rows, hasLength(2));
      final latest = rows.last;
      expect(latest.startDate, day(8));
      expect(latest.endDate, day(14));
      expect(latest.repeats, isTrue);
      expect(rows.first.repeats, isFalse);
    });
  });

  group('the card on Home', () {
    testWithDatabase('is not there while nothing is running', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await ChallengesRepository(db).create(
        title: 'Next week',
        kind: ChallengeKind.noSpend,
        startDate: day(14),
        endDate: day(20),
      );

      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('challenge-home-card')), findsNothing);
    });

    testWithDatabase('shows the running challenge that ends soonest', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      final repo = ChallengesRepository(db);
      await repo.create(
        title: 'Long one',
        kind: ChallengeKind.noSpend,
        startDate: day(1),
        endDate: day(30),
      );
      await repo.create(
        title: 'Short one',
        kind: ChallengeKind.limit,
        startDate: day(10),
        endDate: day(13),
        limit: 50000,
      );

      await pumpAppWithDatabase(tester, db);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('challenge-home-card')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('challenge-home-title')))
            .data,
        'Short one',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('challenge-home-status')))
            .data,
        '৳500.00 left to spend · 3 days to go',
      );
      expect(find.text('+1 more'), findsOneWidget);
    });
  });
}
