import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/bazar/domain/form_inbox.dart';

void main() {
  group('sheetCsvUri', () {
    test('makes the published link a CSV link', () {
      final uri = sheetCsvUri(
        'https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub?output=html',
      );

      expect(uri.path, '/spreadsheets/d/e/2PACX-abc/pub');
      expect(uri.queryParameters['output'], 'csv');
    });

    test('keeps the sheet of a published link', () {
      final uri = sheetCsvUri(
        'https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub?gid=77&single=true&output=csv',
      );

      expect(uri.queryParameters['gid'], '77');
      expect(uri.queryParameters['output'], 'csv');
    });

    test('turns the link of a viewable sheet into an export', () {
      final uri = sheetCsvUri(
        'https://docs.google.com/spreadsheets/d/1AbC/edit?usp=sharing#gid=55',
      );

      expect(uri.path, '/spreadsheets/d/1AbC/export');
      expect(uri.queryParameters, {'format': 'csv', 'gid': '55'});
    });

    test('refuses a link that is not a Google Sheet', () {
      for (final link in [
        '',
        'rice and eggs',
        'http://docs.google.com/spreadsheets/d/e/x/pub',
        'https://example.com/spreadsheets/d/e/x/pub',
        'https://docs.google.com/document/d/1AbC/edit',
      ]) {
        expect(
          () => sheetCsvUri(link),
          throwsA(isA<ValidationException>()),
          reason: link,
        );
      }
    });
  });

  group('readFormRows', () {
    List<String> names(List<FormRow> rows) => [
      for (final row in rows) ...row.names,
    ];

    test('takes the Item column of a form, not the time', () {
      final rows = readFormRows(
        'Timestamp,Item\n10/25/2026 10:00:00,Rice\n10/25/2026 10:05:00,Egg\n',
      );

      expect(names(rows), ['Rice', 'Egg']);
      expect(rows, hasLength(2));
    });

    test('finds the Item column wherever it is, and reads a quantity', () {
      final rows = readFormRows(
        'Timestamp,How many,Item (what to buy)\n'
        '10/25/2026 10:00:00,3,Onion\n'
        '10/25/2026 10:05:00,,Salt\n',
      );

      expect(rows.first.names, ['Onion']);
      expect(rows.first.quantity, 3);
      expect(rows.last.quantity, 1);
    });

    test('uses the second column when no title says item', () {
      final rows = readFormRows('Timestamp,Answer\n10/25/2026,Dal\n');

      expect(names(rows), ['Dal']);
    });

    test('squeezes blanks and keeps a row with no item as a row', () {
      final rows = readFormRows(
        'Timestamp,Item\n10/25/2026,  Green   chilli \n10/25/2026 11:00,\n',
      );

      expect(rows.first.names, ['Green chilli']);
      expect(rows, hasLength(2));
      expect(rows.last.names, isEmpty);
    });

    test('splits an answer with several things, one on each line', () {
      final rows = readFormRows(
        'Timestamp,Item\n10/25/2026,"Rice\nEgg\n\nSalt"\n',
      );

      expect(rows, hasLength(1));
      expect(rows.single.names, ['Rice', 'Egg', 'Salt']);
    });

    test('splits at commas and semicolons too', () {
      final rows = readFormRows(
        'Timestamp,Item\n10/25/2026,"Rice, Egg; Salt"\n',
      );

      expect(rows.single.names, ['Rice', 'Egg', 'Salt']);
    });

    test('takes a list mark off the front of each thing', () {
      final rows = readFormRows(
        'Timestamp,Item\n10/25/2026,"- Rice\n• Egg\n3. Salt\n২) Dal"\n',
      );

      expect(rows.single.names, ['Rice', 'Egg', 'Salt', 'Dal']);
    });

    test('a quantity is only read for an answer with one thing', () {
      final rows = readFormRows(
        'Timestamp,Item,Quantity\n'
        '10/25/2026,Rice,5\n'
        '10/25/2026,"Egg, Salt",5\n',
      );

      expect(rows.first.quantity, 5);
      expect(rows.last.quantity, 1);
    });
  });

  group('planFormImport', () {
    final rows = [
      const FormRow(names: ['Rice']),
      const FormRow(names: ['Egg']),
      const FormRow(names: ['Salt']),
    ];

    List<String> names(FormImportPlan plan) => [
      for (final item in plan.toAdd) item.name,
    ];

    test('takes the rows after the ones taken before', () {
      final plan = planFormImport(rows: rows, imported: 1);

      expect(names(plan), ['Egg', 'Salt']);
      expect(plan.imported, 3);
    });

    test('takes nothing when nothing is new', () {
      final plan = planFormImport(rows: rows, imported: 3);

      expect(plan.toAdd, isEmpty);
      expect(plan.imported, 3);
    });

    test('takes all of them the first time when told to start from 0', () {
      expect(planFormImport(rows: rows, imported: 0).toAdd, hasLength(3));
    });

    test('a cleaned sheet takes nothing and counts from there', () {
      final plan = planFormImport(rows: [rows.first], imported: 5);

      expect(plan.toAdd, isEmpty);
      expect(plan.imported, 1);
    });

    test('counts a row without an item but adds nothing for it', () {
      final plan = planFormImport(
        rows: [
          const FormRow(names: []),
          const FormRow(names: ['Dal']),
        ],
        imported: 0,
      );

      expect(names(plan), ['Dal']);
      expect(plan.imported, 2);
    });

    test('a row with several things adds each, and counts once', () {
      final plan = planFormImport(
        rows: [
          const FormRow(names: ['Rice', 'Egg', 'Salt']),
        ],
        imported: 0,
      );

      expect(names(plan), ['Rice', 'Egg', 'Salt']);
      expect(plan.imported, 1);
    });
  });
}
