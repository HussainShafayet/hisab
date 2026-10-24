import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

final search = find.byKey(const ValueKey('more-search'));

Future<void> openMore(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('More'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the search box of More', () {
    testWithDatabase('finds a place by its name', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMore(tester);

      await tester.enterText(search, 'zak');
      await tester.pumpAndSettle();

      expect(find.text('Zakat'), findsOneWidget);
      expect(find.text('Loans'), findsNothing);
      // The headings are not needed for a short list.
      expect(find.text('Faith'), findsNothing);
    });

    testWithDatabase('finds a place by what it is for', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMore(tester);

      await tester.enterText(search, 'bkash');
      await tester.pumpAndSettle();

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Zakat'), findsNothing);
    });

    testWithDatabase('says so when nothing matches', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMore(tester);

      await tester.enterText(search, 'xyzzy');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('more-search-empty')), findsOneWidget);
      expect(find.text('Zakat'), findsNothing);
    });

    testWithDatabase('opens the place that was found', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMore(tester);
      await tester.enterText(search, 'zak');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Zakat'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Zakat')),
        findsOneWidget,
      );
    });

    testWithDatabase('shows the whole list again when cleared', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openMore(tester);
      await tester.enterText(search, 'zak');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('more-search-clear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('more-help')), findsOneWidget);
      expect(find.text('Faith'), findsOneWidget);
    });
  });
}
