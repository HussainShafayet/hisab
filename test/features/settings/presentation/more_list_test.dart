import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';

import '../../../helpers/pump_app.dart';

Future<void> openMoreTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('More'),
    ),
  );
  await tester.pumpAndSettle();
}

// Today is Sunday 11 October 2026.
void main() {
  group('the More list', () {
    testWithDatabase('puts each group in a card', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMoreTab(tester);

      expect(find.byKey(const ValueKey('more-group-Money')), findsOneWidget);
      expect(find.byKey(const ValueKey('more-recent')), findsNothing);
    });

    testWithDatabase('remembers the places opened and offers them again', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMoreTab(tester);

      await tapMoreRow(tester, 'Accounts');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('more-recent')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recent-${AppRoutes.accounts}')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('recent-${AppRoutes.accounts}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accounts'), findsWidgets);
    });

    testWithDatabase('says there is no backup yet', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMoreTab(tester);

      final status = find.byKey(
        const ValueKey('more-status-${AppRoutes.backup}'),
      );
      await tester.scrollUntilVisible(
        status,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(tester.widget<Text>(status).data, 'No backup yet');
    });

    testWithDatabase('says how many loans are late', (tester, db) async {
      useTallScreen(tester);
      await DebtsRepository(db).createDebt(
        person: 'Rahim',
        direction: DebtDirection.lent,
        amount: 100000,
        openedOn: DateTime(2026, 9, 1),
        dueOn: DateTime(2026, 10, 1),
      );
      await pumpAppWithDatabase(tester, db);
      await openMoreTab(tester);

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('more-status-${AppRoutes.debts}')),
            )
            .data,
        '1 late',
      );
    });
  });
}
