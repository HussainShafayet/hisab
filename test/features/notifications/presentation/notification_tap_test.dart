import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_route.dart';
import 'package:hishab/core/router/app_routes.dart';

import '../../../helpers/pump_app.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

void main() {
  tearDown(() => pendingNotificationRoute.value = null);

  group('a tap on a notification on the phone', () {
    testWithDatabase('opens the screen it is about, on top', (
      tester,
      db,
    ) async {
      await pumpAppWithDatabase(tester, db);

      pendingNotificationRoute.value = AppRoutes.zakat;
      await tester.pumpAndSettle();

      expect(appBarTitle('Zakat'), findsOneWidget);
      expect(pendingNotificationRoute.value, isNull);
      // Back goes to where the person was.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(appBarTitle('Home'), findsOneWidget);
    });

    testWithDatabase('switches to a tab', (tester, db) async {
      await pumpAppWithDatabase(tester, db);

      pendingNotificationRoute.value = AppRoutes.budget;
      await tester.pumpAndSettle();

      expect(appBarTitle('Budget'), findsOneWidget);
      expect(pendingNotificationRoute.value, isNull);
    });

    testWithDatabase('that came before the app was ready is opened too', (
      tester,
      db,
    ) async {
      pendingNotificationRoute.value = AppRoutes.debts;

      await pumpAppWithDatabase(tester, db);
      await tester.pumpAndSettle();

      expect(appBarTitle('Loans'), findsOneWidget);
      expect(pendingNotificationRoute.value, isNull);
    });
  });
}
