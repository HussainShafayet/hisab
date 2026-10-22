import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/goals/data/goals_repository.dart';

import '../../../helpers/pump_app.dart';
import 'festival_ui_test.dart' show festival, openGoals;

// Today is Sunday 11 October 2026. Eid-ul-Fitr is about 10 March 2027, Pohela
// Boishakh is 14 April 2027 and Eid-ul-Adha about 17 May 2027.

Future<void> openMenu(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('festival-menu-$name')));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> openGoalsScreen(WidgetTester tester, db) async {
  useTallScreen(tester);
  await pumpAppWithDatabase(tester, db);
  await openGoals(tester);
}

void main() {
  group('the menu of a festival', () {
    testWithDatabase('has a way to change the date and to hide it', (
      tester,
      db,
    ) async {
      await openGoalsScreen(tester, db);

      await openMenu(tester, 'eidUlFitr');

      expect(find.text('Change the date'), findsOneWidget);
      expect(find.text('Hide this festival'), findsOneWidget);
      // No fund yet, and no day set.
      expect(find.text('Edit fund'), findsNothing);
      expect(find.text('Delete fund'), findsNothing);
      expect(find.text('Use the usual date'), findsNothing);
    });

    testWithDatabase('hiding takes the card away, and Undo brings it back', (
      tester,
      db,
    ) async {
      await openGoalsScreen(tester, db);

      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Hide this festival');

      expect(festival('eidUlFitr'), findsNothing);
      expect(festival('pohelaBoishakh'), findsOneWidget);
      expect(find.text('Eid-ul-Fitr hidden'), findsOneWidget);
      expect(find.text('Show 1 hidden festival'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(festival('eidUlFitr'), findsOneWidget);
      expect(find.byKey(const ValueKey('show-hidden-festivals')), findsNothing);
    });

    testWithDatabase('Show hidden festivals brings them all back', (
      tester,
      db,
    ) async {
      await openGoalsScreen(tester, db);
      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Hide this festival');
      await openMenu(tester, 'pohelaBoishakh');
      await choose(tester, 'Hide this festival');
      expect(find.text('Show 2 hidden festivals'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('show-hidden-festivals')));
      await tester.pumpAndSettle();

      expect(festival('eidUlFitr'), findsOneWidget);
      expect(festival('pohelaBoishakh'), findsOneWidget);
      expect(festival('eidUlAdha'), findsOneWidget);
    });

    testWithDatabase('all of them can be hidden, and the button stays', (
      tester,
      db,
    ) async {
      await openGoalsScreen(tester, db);

      for (final name in ['eidUlFitr', 'pohelaBoishakh', 'eidUlAdha']) {
        await openMenu(tester, name);
        await choose(tester, 'Hide this festival');
      }

      expect(festival('eidUlFitr'), findsNothing);
      expect(festival('pohelaBoishakh'), findsNothing);
      expect(festival('eidUlAdha'), findsNothing);
      expect(find.text('Show 3 hidden festivals'), findsOneWidget);
    });

    testWithDatabase('a hidden festival is kept in the settings', (
      tester,
      db,
    ) async {
      await openGoalsScreen(tester, db);

      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Hide this festival');

      final saved = (await db.settingsDao.getAll())['festival_settings'];
      expect(saved, contains('eidUlFitr'));
    });
  });

  group('changing the day of a festival', () {
    testWithDatabase('sets the day, which is then not a guess', (
      tester,
      db,
    ) async {
      await openGoalsScreen(tester, db);
      expect(find.text('About Mar 10'), findsOneWidget);

      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Change the date');
      expect(find.text('The day of Eid-ul-Fitr'), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Mar 15'), findsOneWidget);
      expect(find.text('About Mar 10'), findsNothing);
      expect(find.text('155 days to go'), findsOneWidget);
    });

    testWithDatabase('Use the usual date goes back', (tester, db) async {
      await openGoalsScreen(tester, db);
      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Change the date');
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Use the usual date');

      expect(find.text('About Mar 10'), findsOneWidget);
      expect(find.text('150 days to go'), findsOneWidget);
    });

    testWithDatabase('Cancel keeps the day', (tester, db) async {
      await openGoalsScreen(tester, db);
      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Change the date');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('About Mar 10'), findsOneWidget);
    });

    testWithDatabase('the fund keeps the day of the festival', (
      tester,
      db,
    ) async {
      final repo = GoalsRepository(db);
      final id = await repo.createGoal(
        name: 'Eid-ul-Fitr 2027',
        target: 5000000,
        targetDate: DateTime(2027, 3, 10),
        icon: 'gift',
      );
      await openGoalsScreen(tester, db);

      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Change the date');
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect((await repo.getGoal(id))!.goal.targetDate, DateTime(2027, 3, 12));
      // And it is still the fund of the festival.
      expect(
        find.byKey(const ValueKey('festival-start-eidUlFitr')),
        findsNothing,
      );
    });
  });

  group('the fund of a festival', () {
    Future<int> fund(db) => GoalsRepository(db).createGoal(
      name: 'Eid-ul-Fitr 2027',
      target: 5000000,
      targetDate: DateTime(2027, 3, 10),
      icon: 'gift',
    );

    testWithDatabase('can be edited from the festival', (tester, db) async {
      await fund(db);
      await openGoalsScreen(tester, db);

      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Edit fund');

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Edit goal'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('can be deleted from the festival, after asking', (
      tester,
      db,
    ) async {
      final id = await fund(db);
      await openGoalsScreen(tester, db);
      expect(
        find.byKey(const ValueKey('festival-start-eidUlFitr')),
        findsNothing,
      );

      await openMenu(tester, 'eidUlFitr');
      await choose(tester, 'Delete fund');
      expect(find.text('Delete "Eid-ul-Fitr 2027"?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-delete-goal')));
      await tester.pumpAndSettle();

      expect(await GoalsRepository(db).getGoal(id), isNull);
      // The festival is still there, asking for a fund again.
      expect(
        find.byKey(const ValueKey('festival-start-eidUlFitr')),
        findsOneWidget,
      );
    });
  });

  group('the menu of a goal', () {
    testWithDatabase('Edit opens the form of the goal', (tester, db) async {
      final id = await GoalsRepository(db)
          .createGoal(name: 'Laptop', target: 8000000, icon: 'laptop');
      await openGoalsScreen(tester, db);

      await tester.tap(find.byKey(ValueKey('goal-menu-$id')));
      await tester.pumpAndSettle();
      await choose(tester, 'Edit');

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Edit goal'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('Delete asks, then removes the goal', (tester, db) async {
      final repo = GoalsRepository(db);
      final id = await repo.createGoal(name: 'Laptop', target: 8000000);
      final trip = await repo.createGoal(name: 'Trip', target: 3000000);
      await openGoalsScreen(tester, db);

      await tester.tap(find.byKey(ValueKey('goal-menu-$id')));
      await tester.pumpAndSettle();
      await choose(tester, 'Delete');
      expect(find.text('Delete "Laptop"?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-delete-goal')));
      await tester.pumpAndSettle();

      expect(await repo.getGoal(id), isNull);
      expect(await repo.getGoal(trip), isNotNull);
      expect(find.text('Laptop'), findsNothing);
    });

    testWithDatabase('Cancel keeps the goal', (tester, db) async {
      final id = await GoalsRepository(db)
          .createGoal(name: 'Laptop', target: 8000000);
      await openGoalsScreen(tester, db);

      await tester.tap(find.byKey(ValueKey('goal-menu-$id')));
      await tester.pumpAndSettle();
      await choose(tester, 'Delete');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await GoalsRepository(db).getGoal(id), isNotNull);
    });
  });
}
