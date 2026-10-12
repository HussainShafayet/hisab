import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';

import '../../../helpers/test_database.dart';

void main() {
  test('reads a header row and the data rows', () {
    final table = parseCsvTable(
      'Date,Amount,Note\n11/10/2026,250,Lunch\n12/10/2026,80,Tea\n',
    );

    expect(table.headers, ['Date', 'Amount', 'Note']);
    expect(table.rows, [
      ['11/10/2026', '250', 'Lunch'],
      ['12/10/2026', '80', 'Tea'],
    ]);
    expect(table.columnCount, 3);
    expect(table.cell(1, 2), 'Tea');
  });

  test('without a header row every row is data', () {
    final table = parseCsvTable(
      '11/10/2026,250\n12/10/2026,80',
      hasHeader: false,
    );

    expect(table.headers, ['Column 1', 'Column 2']);
    expect(table.rows, hasLength(2));
    expect(table.rows.first, ['11/10/2026', '250']);
  });

  test('finds semicolons and tabs by itself', () {
    expect(parseCsvTable('Date;Amount\n11/10/2026;250').rows.single, [
      '11/10/2026',
      '250',
    ]);
    expect(parseCsvTable('Date\tAmount\n11/10/2026\t250').rows.single, [
      '11/10/2026',
      '250',
    ]);
  });

  test('quoted cells may hold separators, quotes and line breaks', () {
    final table = parseCsvTable(
      'Date,Note\n'
      '11/10/2026,"Lunch, with Rahim"\n'
      '12/10/2026,"He said ""hi"""\n'
      '13/10/2026,"two\nlines"\n',
    );

    expect(table.rows[0][1], 'Lunch, with Rahim');
    expect(table.rows[1][1], 'He said "hi"');
    expect(table.rows[2][1], 'two\nlines');
  });

  test('ignores a byte order mark, empty lines and windows line ends', () {
    final table = parseCsvTable(
      '﻿Date,Amount\r\n\r\n11/10/2026,250\r\n\r\n,\r\n',
    );

    expect(table.headers, ['Date', 'Amount']); // no invisible mark on "Date"
    expect(table.rows, [
      ['11/10/2026', '250'],
    ]);
  });

  test('trims every cell', () {
    final table = parseCsvTable(' Date , Amount \n 11/10/2026 , 250 ');

    expect(table.headers, ['Date', 'Amount']);
    expect(table.rows.single, ['11/10/2026', '250']);
  });

  test('pads short rows so every row has a cell for each column', () {
    final table = parseCsvTable('A,B,C\n1\n1,2,3');

    expect(table.rows[0], ['1', '', '']);
    expect(table.cell(0, 2), '');
  });

  test('a column that is not there reads as empty', () {
    final table = parseCsvTable('A,B\n1,2');

    expect(table.cell(0, 5), '');
    expect(table.cell(0, -1), '');
  });

  test('keeps Bengali text', () {
    final table = parseCsvTable('তারিখ,বিবরণ\n১১/১০/২০২৬,চা');

    expect(table.headers, ['তারিখ', 'বিবরণ']);
    expect(table.rows.single, ['১১/১০/২০২৬', 'চা']);
  });

  test('says so when the file has nothing in it', () {
    expect(() => parseCsvTable(''), throwsValidation('no rows'));
    expect(() => parseCsvTable('\n\n  \n'), throwsValidation('no rows'));
  });

  test('a file with only a header has no data rows', () {
    final table = parseCsvTable('Date,Amount');

    expect(table.headers, ['Date', 'Amount']);
    expect(table.rows, isEmpty);
  });
}
