import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Finder navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWithDatabase('starts on Home with five tabs and the add button', (
    tester,
    db,
  ) async {
    await pumpAppWithDatabase(tester, db);

    expect(appBarTitle('Home'), findsOneWidget);
    for (final label in ['Home', 'Transactions', 'Budget', 'Reports', 'More']) {
      expect(navDestination(label), findsOneWidget);
    }
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWithDatabase('each tab shows its own screen', (tester, db) async {
    await pumpAppWithDatabase(tester, db);

    for (final label in ['Transactions', 'Budget', 'Reports', 'More', 'Home']) {
      await tester.tap(navDestination(label));
      await tester.pumpAndSettle();
      expect(appBarTitle(label), findsOneWidget, reason: label);
    }
  });

  testWithDatabase('add button opens the add form above the tabs', (
    tester,
    db,
  ) async {
    await pumpAppWithDatabase(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(appBarTitle('Add transaction'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(appBarTitle('Home'), findsOneWidget);
  });

  testWithDatabase('More tab opens its sub screens full screen', (
    tester,
    db,
  ) async {
    await pumpAppWithDatabase(tester, db);
    await tester.tap(navDestination('More'));
    await tester.pumpAndSettle();

    // Accounts and Categories have real screens with their own tests.
    for (final title in ['Backup & export', 'Settings']) {
      await tapMoreRow(tester, title);
      expect(appBarTitle(title), findsOneWidget, reason: title);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appBarTitle('More'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });
}
