import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// The "Leave without saving?" question, tried on the goal form.
Future<void> openNewGoal(WidgetTester tester) async {
  await openFromMore(tester, 'Savings goals');
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  group('leaving a form', () {
    testWithDatabase('goes back at once when nothing was typed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openNewGoal(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('discard-dialog')), findsNothing);
      expect(find.byKey(const ValueKey('goal-name')), findsNothing);
    });

    testWithDatabase('asks first when something was typed', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openNewGoal(tester);
      await tester.enterText(find.byKey(const ValueKey('goal-name')), 'Laptop');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Leave without saving?'), findsOneWidget);
      expect(find.byKey(const ValueKey('goal-name')), findsOneWidget);
    });

    testWithDatabase('stays on the form when the answer is keep editing', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openNewGoal(tester);
      await tester.enterText(find.byKey(const ValueKey('goal-name')), 'Laptop');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('discard-keep')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('discard-dialog')), findsNothing);
      expect(find.text('Laptop'), findsOneWidget);
    });

    testWithDatabase('goes back when the answer is leave', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openNewGoal(tester);
      await tester.enterText(find.byKey(const ValueKey('goal-name')), 'Laptop');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('discard-leave')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('goal-name')), findsNothing);
      expect(find.text('Laptop'), findsNothing);
    });

    testWithDatabase('does not ask after saving', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openNewGoal(tester);
      await tester.enterText(find.byKey(const ValueKey('goal-name')), 'Laptop');
      await tester.enterText(find.byKey(const ValueKey('goal-target')), '1000');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('goal-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('discard-dialog')), findsNothing);
      expect(find.byKey(const ValueKey('goal-name')), findsNothing);
      expect(find.text('Laptop'), findsOneWidget);
    });
  });
}
