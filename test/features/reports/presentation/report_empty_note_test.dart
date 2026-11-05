import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import 'reports_screen_test.dart' show openReports, seedReports;

void main() {
  group('a report with nothing in it', () {
    testWithDatabase('says so on top and offers to add an entry', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(find.byKey(const ValueKey('report-nothing')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-add-entry')));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsWidgets);
    });

    testWithDatabase('has no such note when something was recorded', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(find.byKey(const ValueKey('report-nothing')), findsNothing);
    });
  });
}
