import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/bazar/data/form_inbox_gateway.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fake_form_inbox_gateway.dart';
import '../../../helpers/pump_app.dart';

const sheetLink =
    'https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub?output=csv';
const formLink = 'https://forms.gle/abc123';
final status = find.byKey(const ValueKey('form-status'));

/// Real time for the database, which does not run in the test's fake time.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

Future<void> openBazar(WidgetTester tester) async {
  await openFromMore(tester, 'Bazar list');
  await settle(tester);
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('bazar-menu')));
  await tester.pumpAndSettle();
}

Future<void> link(
  WidgetTester tester, {
  String sheet = sheetLink,
  String form = '',
}) async {
  await openMenu(tester);
  await tester.tap(find.byKey(const ValueKey('bazar-menu-form-setup')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('form-sheet-link')), sheet);
  await tester.enterText(find.byKey(const ValueKey('form-link')), form);
  await tester.tap(find.byKey(const ValueKey('form-link-ok')));
  await settle(tester);
}

Future<void> putLinked(dynamic db, {String? form}) async {
  await db.settingsDao.put(formCsvKey, sheetLink);
  await db.settingsDao.put(formImportedKey, '0');
  if (form != null) await db.settingsDao.put(formLinkKey, form);
}

void main() {
  group('the bazar list with a Google Form', () {
    testWithDatabase('offers to add from a form, and is plain without one', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openBazar(tester);

      expect(status, findsNothing);
      await openMenu(tester);
      expect(
        find.byKey(const ValueKey('bazar-menu-form-setup')),
        findsOneWidget,
      );
      expect(find.text('Sync now'), findsNothing);
    });

    testWithDatabase('links a sheet and takes the answers in it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final gateway = FakeFormInboxGateway()..answer(['Rice', 'Egg']);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [formInboxGatewayProvider.overrideWithValue(gateway)],
      );
      await openBazar(tester);

      await link(tester);
      expect(
        find.text('The sheet already has 2 answers. Add them to the list?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('form-take-all')));
      await settle(tester);

      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Egg'), findsOneWidget);
      expect(
        tester.widget<Text>(status).data,
        startsWith('Google Form · Synced '),
      );
    });

    testWithDatabase('can start from the new answers only', (tester, db) async {
      useTallScreen(tester);
      final gateway = FakeFormInboxGateway()..answer(['Rice']);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [formInboxGatewayProvider.overrideWithValue(gateway)],
      );
      await openBazar(tester);
      await link(tester);

      await tester.tap(find.byKey(const ValueKey('form-only-new')));
      await settle(tester);

      expect(find.text('Rice'), findsNothing);
      expect(status, findsOneWidget);
    });

    testWithDatabase('refuses a link that is not a published sheet', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [
          formInboxGatewayProvider.overrideWithValue(FakeFormInboxGateway()),
        ],
      );
      await openBazar(tester);

      await link(tester, sheet: 'rice');

      expect(find.textContaining('Publish to web'), findsWidgets);
      expect(status, findsNothing);
    });

    testWithDatabase('brings new answers in when the screen opens', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await putLinked(db);
      final gateway = FakeFormInboxGateway()..answer(['Salt']);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [formInboxGatewayProvider.overrideWithValue(gateway)],
      );

      await openBazar(tester);

      expect(find.text('Salt'), findsOneWidget);
    });

    testWithDatabase('has Sync now, and stops when told to', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await putLinked(db);
      final gateway = FakeFormInboxGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [formInboxGatewayProvider.overrideWithValue(gateway)],
      );
      await openBazar(tester);
      gateway.answer(['Onion']);

      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('bazar-menu-form-sync')));
      await settle(tester);
      expect(find.text('Onion'), findsOneWidget);

      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('bazar-menu-form-off')));
      await settle(tester);
      expect(status, findsNothing);
    });

    testWithDatabase('sends the link of the form to others', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await putLinked(db, form: formLink);
      final files = FakeFileGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [
          formInboxGatewayProvider.overrideWithValue(FakeFormInboxGateway()),
          fileGatewayProvider.overrideWithValue(files),
        ],
      );
      await openBazar(tester);

      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('bazar-menu-form-share')));
      await settle(tester);

      expect(files.sharedTexts, [formLink]);
    });

    testWithDatabase('shows what went wrong, in red', (tester, db) async {
      useTallScreen(tester);
      await putLinked(db);
      final gateway = FakeFormInboxGateway()
        ..failWith = FormInboxProblem.notPublished;
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [formInboxGatewayProvider.overrideWithValue(gateway)],
      );

      await openBazar(tester);

      expect(tester.widget<Text>(status).data, contains('Publish to web'));
    });
  });
}
