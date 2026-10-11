import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/app.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';

import 'test_database.dart';

/// A widget test with its own in-memory database (empty unless
/// [seedDefaults]). Seed rows through `db`, then call [pumpAppWithDatabase].
///
/// drift keeps a zero-length timer alive after the last stream listener goes
/// away, and Flutter fails a test that ends with a timer pending. So the
/// widget tree is removed, the timer is allowed to fire and the database is
/// closed inside the test body, not in a tearDown.
void testWithDatabase(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body, {
  bool seedDefaults = false,
}) {
  testWidgets(description, (tester) async {
    final db = createTestDatabase(seedDefaults: seedDefaults);
    try {
      await body(tester, db);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      await db.close();
    }
  });
}

/// The time the app believes it is in widget tests: Sunday 11 October 2026.
final testNow = DateTime(2026, 10, 11, 14, 30);

/// Runs the whole app on [db] and waits until it settles. The app's clock
/// stands still at [now].
Future<void> pumpAppWithDatabase(
  WidgetTester tester,
  AppDatabase db, {
  DateTime? now,
}) async {
  final time = now ?? testNow;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => time),
      ],
      child: const HishabApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The list row whose title is exactly [title]. Matches on the title only, so
/// a row whose subtitle repeats the text (an account named "Cash" of type
/// Cash) is still found once.
Finder listRow(String title) => find.byWidgetPredicate(
  (widget) =>
      widget is ListTile &&
      widget.title is Text &&
      (widget.title! as Text).data == title,
  description: 'ListTile titled "$title"',
);

/// Opens a screen listed on the More tab, e.g. "Accounts".
Future<void> openFromMore(WidgetTester tester, String title) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('More'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(listRow(title));
  await tester.pumpAndSettle();
}

/// Taps the "more actions" menu of the list row whose title is [rowTitle]
/// and waits for the menu to open.
Future<void> openRowMenu(WidgetTester tester, String rowTitle) async {
  await tester.tap(
    find.descendant(
      of: listRow(rowTitle),
      matching: find.byIcon(Icons.more_vert),
    ),
  );
  await tester.pumpAndSettle();
}

/// Gives the test a tall phone-sized screen so long lists and forms are fully
/// on screen without scrolling.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
