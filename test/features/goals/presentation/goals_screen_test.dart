import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/goals/data/goals_repository.dart';

import '../../../helpers/pump_app.dart';

// "Now" in widget tests is Sunday 11 October 2026.
Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<int> makeGoal(
  AppDatabase db, {
  String name = 'Laptop',
  int target = 100000,
  int saved = 0,
  DateTime? day,
}) async {
  final repo = GoalsRepository(db);
  final id = await repo.createGoal(name: name, target: target, targetDate: day);
  if (saved != 0) {
    await repo.addEntry(id, amount: saved, date: DateTime(2026, 10, 1));
  }
  return id;
}

void main() {
  group('the goals list', () {
    testWithDatabase('invites you to make the first goal', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');

      expect(find.text('No goals yet'), findsOneWidget);
    });

    testWithDatabase('shows how far each goal has come', (tester, db) async {
      useTallScreen(tester);
      final laptop = await makeGoal(db, saved: 25000);
      await makeGoal(db, name: 'Eid', target: 50000, saved: 50000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');

      expect(textOf(tester, 'goal-amounts-$laptop'), '৳250.00 of ৳1,000.00');
      expect(textOf(tester, 'goal-percent-$laptop'), '25%');
      expect(textOf(tester, 'goal-hint-$laptop'), '৳750.00 to go');
      expect(find.text('Goal reached'), findsOneWidget);
      expect(textOf(tester, 'goals-saved'), '৳750.00');
      expect(
        textOf(tester, 'goals-summary'),
        'of ৳1,500.00 in 2 goals, 1 reached',
      );
    });

    testWithDatabase('says how much to put aside each month', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      // ৳1,000 to go, 90 days from 11 October.
      final id = await makeGoal(db, day: DateTime(2027, 1, 9));
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');

      expect(
        textOf(tester, 'goal-hint-$id'),
        'Put aside ৳333.34 a month to reach it by 9 Jan 2027',
      );
    });
  });

  group('making a goal', () {
    testWithDatabase('saves the name and target', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await enter(tester, 'goal-name', 'New phone');
      await enter(tester, 'goal-target', '30000');
      await tapKey(tester, 'goal-icon-phone');
      await tapKey(tester, 'goal-save');

      final goals = await db.goalsDao.getAllGoals();
      expect(goals.single.name, 'New phone');
      expect(goals.single.target, 3000000);
      expect(goals.single.icon, 'phone');
      expect(find.text('New phone'), findsOneWidget);
    });

    testWithDatabase('needs a name and a target', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tapKey(tester, 'goal-save');

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(await db.goalsDao.getAllGoals(), isEmpty);
    });
  });

  group('a goal', () {
    testWithDatabase('takes money put in and taken out', (tester, db) async {
      useTallScreen(tester);
      final id = await makeGoal(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');
      await tapKey(tester, 'goal-$id');

      expect(appBarTitle('Laptop'), findsOneWidget);
      expect(find.byKey(const ValueKey('no-entries')), findsOneWidget);

      await tapKey(tester, 'put-in');
      await enter(tester, 'goal-money-amount', '400');
      await tapKey(tester, 'goal-money-save');
      expect(textOf(tester, 'goal-saved'), '৳400.00');
      expect(textOf(tester, 'goal-percent'), '40%');

      await tapKey(tester, 'take-out');
      await enter(tester, 'goal-money-amount', '150');
      await tapKey(tester, 'goal-money-save');
      expect(textOf(tester, 'goal-saved'), '৳250.00');
      expect(find.text('+৳400.00'), findsOneWidget);
      expect(find.text('-৳150.00'), findsOneWidget);
    });

    testWithDatabase('cannot give back more than it holds', (tester, db) async {
      useTallScreen(tester);
      final id = await makeGoal(db, saved: 10000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');
      await tapKey(tester, 'goal-$id');

      await tapKey(tester, 'take-out');
      await enter(tester, 'goal-money-amount', '500');
      await tapKey(tester, 'goal-money-save');

      expect(find.text('Only ৳100.00 is saved in this goal.'), findsOneWidget);
      expect(textOf(tester, 'goal-saved'), '৳100.00');
    });

    testWithDatabase('has no "Take out" while nothing is saved', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await makeGoal(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');
      await tapKey(tester, 'goal-$id');

      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('take-out')),
      );
      expect(button.onPressed, isNull);
    });

    testWithDatabase('is deleted with its entries', (tester, db) async {
      useTallScreen(tester);
      final id = await makeGoal(db, saved: 10000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');
      await tapKey(tester, 'goal-$id');

      await tapKey(tester, 'goal-menu');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'confirm-delete-goal');

      expect(await db.goalsDao.getAllGoals(), isEmpty);
      expect(await db.goalsDao.getAllEntries(), isEmpty);
      expect(find.text('No goals yet'), findsOneWidget);
    });

    testWithDatabase('has an entry removed', (tester, db) async {
      useTallScreen(tester);
      final id = await makeGoal(db, saved: 10000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Savings goals');
      await tapKey(tester, 'goal-$id');
      final entry = (await db.goalsDao.getAllEntries()).single;

      await tapKey(tester, 'delete-entry-${entry.id}');
      await tapKey(tester, 'confirm-delete-entry');

      expect(textOf(tester, 'goal-saved'), '৳0.00');
      expect(find.byKey(const ValueKey('no-entries')), findsOneWidget);
    });
  });
}
