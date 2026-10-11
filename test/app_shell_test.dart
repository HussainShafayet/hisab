import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/app.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: HishabApp()));
  await tester.pumpAndSettle();
}

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Finder navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('starts on Home with five tabs and the add button', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(appBarTitle('Home'), findsOneWidget);
    for (final label in ['Home', 'Transactions', 'Budget', 'Reports', 'More']) {
      expect(navDestination(label), findsOneWidget);
    }
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('each tab shows its own screen', (tester) async {
    await pumpApp(tester);

    for (final label in ['Transactions', 'Budget', 'Reports', 'More', 'Home']) {
      await tester.tap(navDestination(label));
      await tester.pumpAndSettle();
      expect(appBarTitle(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('add button opens the add screen above the tabs', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(appBarTitle('Add transaction'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(appBarTitle('Home'), findsOneWidget);
  });

  testWidgets('More tab opens its sub screens full screen', (tester) async {
    await pumpApp(tester);
    await tester.tap(navDestination('More'));
    await tester.pumpAndSettle();

    // Accounts and Categories have real screens that need a database, so
    // they are covered in the accounts and categories screen tests.
    for (final title in ['Backup & export', 'Settings']) {
      await tester.tap(find.widgetWithText(ListTile, title));
      await tester.pumpAndSettle();
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
