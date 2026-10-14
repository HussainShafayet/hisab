import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

const _banner = ValueKey('parent-suggestion');

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
  await tester.pump();
}

String parentValue(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('parent-value'))).data!;

void main() {
  testWithDatabase('suggests the group while a name is typed', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await openForm(tester);

    expect(find.byKey(_banner), findsNothing);
    await typeName(tester, 'Fuchka masala');

    expect(find.byKey(_banner), findsOneWidget);
    expect(
      find.text('Looks like it goes inside Fuchka & chotpoti.'),
      findsOneWidget,
    );
    expect(parentValue(tester), 'Top level');
  }, seedDefaults: true);

  testWithDatabase('puts the category there with one tap', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await openForm(tester);
    await typeName(tester, 'Fuchka masala');

    await tester.tap(find.byKey(const ValueKey('parent-suggestion-apply')));
    await tester.pump();

    expect(parentValue(tester), contains('Fuchka & chotpoti'));
    expect(find.byKey(_banner), findsNothing);
  }, seedDefaults: true);

  testWithDatabase('follows the name and goes away when it fits nowhere', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await openForm(tester);

    await typeName(tester, 'Rickshaw fare');
    expect(find.text('Looks like it goes inside City travel.'), findsOneWidget);
    await typeName(tester, 'Xyzzy');
    expect(find.byKey(_banner), findsNothing);
  }, seedDefaults: true);

  testWithDatabase('has nothing to say on a brand-new install', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await openForm(tester);
    await typeName(tester, 'Fuchka masala');

    expect(find.byKey(_banner), findsNothing);
  });

  testWithDatabase('explains what "Inside" means', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await openForm(tester);

    expect(
      find.textContaining('The bigger group it belongs to'),
      findsOneWidget,
    );
  });
}
