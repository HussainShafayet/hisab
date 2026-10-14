import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/goals/data/goals_repository.dart';

import '../../../helpers/pump_app.dart';

Future<void> openGoals(WidgetTester tester) async {
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Savings goals'));
  await tester.pumpAndSettle();
}

Finder festival(String name) => find.byKey(ValueKey('festival-$name'));

void main() {
  testWithDatabase('the goals screen lists the coming festivals', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openGoals(tester);

    expect(festival('eidUlFitr'), findsOneWidget);
    expect(festival('eidUlAdha'), findsOneWidget);
    expect(festival('pohelaBoishakh'), findsOneWidget);
    expect(find.text('150 days to go'), findsOneWidget);
    // Still the empty state for goals.
    expect(find.text('No goals yet'), findsOneWidget);
  });

  testWithDatabase('Start a fund opens a goal with the name and day filled', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openGoals(tester);

    await tester.tap(find.byKey(const ValueKey('festival-start-eidUlFitr')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('goal-name')))
          .controller!
          .text,
      'Eid-ul-Fitr 2027',
    );
    expect(find.textContaining('2027'), findsWidgets);
  });

  testWithDatabase('a fund shows its progress and what to put aside', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await GoalsRepository(db).createGoal(
      name: 'Eid-ul-Fitr 2027',
      target: 5000000,
      targetDate: DateTime(2027, 3, 10),
      icon: 'gift',
    );
    await pumpAppWithDatabase(tester, db);
    await openGoals(tester);

    expect(
      find.byKey(const ValueKey('festival-start-eidUlFitr')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('festival-hint-eidUlFitr')),
      findsOneWidget,
    );
    // 150 days: five months of 30 days, 50,000 taka.
    expect(find.text('Put aside ৳10,000.00 a month'), findsOneWidget);
  });

  group('on Home', () {
    testWithDatabase('has no festival card while the festival is far away', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      expect(festival('eidUlFitr'), findsNothing);
    });

    testWithDatabase('counts down to Eid within 120 days', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db, now: DateTime(2027, 2, 1, 10));
      await tester.scrollUntilVisible(
        festival('eidUlFitr'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(festival('eidUlFitr'), findsOneWidget);
      expect(find.text('37 days to go'), findsOneWidget);
      // Only the nearest festival is on Home.
      expect(festival('pohelaBoishakh'), findsNothing);
    });

    testWithDatabase('wishes Eid Mubarak on the day', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db, now: DateTime(2027, 3, 10, 9));
      await tester.scrollUntilVisible(
        festival('eidUlFitr'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Eid Mubarak!'), findsOneWidget);
    });
  });
}
