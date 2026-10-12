import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';

DateTime? parse(String text, SheetDateFormat format) =>
    parseSheetDate(text, format);

void main() {
  const ymd = SheetDateFormat.yearMonthDay;
  const dmy = SheetDateFormat.dayMonthYear;
  const mdy = SheetDateFormat.monthDayYear;

  group('parseSheetDate', () {
    test('reads each order', () {
      expect(parse('2026-10-11', ymd), DateTime(2026, 10, 11, 12));
      expect(parse('11/10/2026', dmy), DateTime(2026, 10, 11, 12));
      expect(parse('10/11/2026', mdy), DateTime(2026, 10, 11, 12));
    });

    test('a date without a time is at noon', () {
      expect(parse('2026-10-11', ymd)!.hour, defaultImportHour);
    });

    test('accepts any separator', () {
      expect(parse('11-10-2026', dmy), DateTime(2026, 10, 11, 12));
      expect(parse('11.10.2026', dmy), DateTime(2026, 10, 11, 12));
      expect(parse('11 10 2026', dmy), DateTime(2026, 10, 11, 12));
      expect(parse('2026/10/11', ymd), DateTime(2026, 10, 11, 12));
    });

    test('accepts single digit days and months', () {
      expect(parse('1/2/2026', dmy), DateTime(2026, 2, 1, 12));
      expect(parse('2026-3-4', ymd), DateTime(2026, 3, 4, 12));
    });

    test('accepts month names', () {
      expect(parse('11 Oct 2026', dmy), DateTime(2026, 10, 11, 12));
      expect(parse('11-October-2026', dmy), DateTime(2026, 10, 11, 12));
      expect(parse('Oct 11, 2026', mdy), DateTime(2026, 10, 11, 12));
      expect(parse('2026 oct 11', ymd), DateTime(2026, 10, 11, 12));
    });

    test('a two digit year means 20xx', () {
      expect(parse('11/10/26', dmy), DateTime(2026, 10, 11, 12));
    });

    test('reads Bengali digits', () {
      expect(parse('১১/১০/২০২৬', dmy), DateTime(2026, 10, 11, 12));
    });

    test('reads a time when there is one', () {
      expect(parse('11/10/2026 14:30', dmy), DateTime(2026, 10, 11, 14, 30));
      expect(
        parse('2026-10-11 09:05:07', ymd),
        DateTime(2026, 10, 11, 9, 5, 7),
      );
      expect(parse('2026-10-11T18:45:00', ymd), DateTime(2026, 10, 11, 18, 45));
      expect(
        parse('2026-10-11T18:45:00Z', ymd),
        DateTime(2026, 10, 11, 18, 45),
      );
    });

    test('reads AM and PM', () {
      expect(parse('11/10/2026 2:30 PM', dmy), DateTime(2026, 10, 11, 14, 30));
      expect(parse('11/10/2026 12:15 AM', dmy), DateTime(2026, 10, 11, 0, 15));
      expect(parse('11/10/2026 12:15 pm', dmy), DateTime(2026, 10, 11, 12, 15));
      expect(parse('11/10/2026 9:00 am', dmy), DateTime(2026, 10, 11, 9));
    });

    test('is null for a date in another order than the format', () {
      expect(parse('11/10/2026', ymd), isNull); // year not first
      expect(parse('2026-10-11', dmy), isNull); // day 2026
      expect(parse('25/12/2026', mdy), isNull); // month 25
    });

    test('is null for days and months that do not exist', () {
      expect(parse('31/02/2026', dmy), isNull);
      expect(parse('29/02/2026', dmy), isNull);
      expect(
        parse('29/02/2028', dmy),
        DateTime(2028, 2, 29, 12),
      ); // a leap year
      expect(parse('00/10/2026', dmy), isNull);
      expect(parse('11/13/2026', dmy), isNull);
      expect(parse('31/04/2026', dmy), isNull);
    });

    test('is null for a bad time or text', () {
      expect(parse('11/10/2026 25:00', dmy), isNull);
      expect(parse('11/10/2026 10:61', dmy), isNull);
      expect(parse('', dmy), isNull);
      expect(parse('yesterday', dmy), isNull);
      expect(parse('11/10', dmy), isNull);
      expect(parse('11/10/2026/5', dmy), isNull);
    });
  });

  group('detectDateFormat', () {
    test('finds a year first', () {
      expect(detectDateFormat(['2026-10-11', '2026-10-12']), ymd);
    });

    test('finds day first when a day is above 12', () {
      expect(detectDateFormat(['11/10/2026', '25/12/2026']), dmy);
    });

    test('finds month first when a month is the only way', () {
      expect(detectDateFormat(['10/11/2026', '12/25/2026']), mdy);
    });

    test('prefers day first when both orders fit', () {
      expect(detectDateFormat(['10/11/2026', '01/02/2026']), dmy);
    });

    test('ignores blank cells', () {
      expect(detectDateFormat(['', '11/10/2026', '  ', '25/12/2026']), dmy);
    });

    test('tolerates a few bad cells but not many', () {
      final mostlyGood = [for (var i = 1; i <= 19; i++) '$i/10/2026', 'oops'];
      expect(detectDateFormat(mostlyGood), dmy); // 19 of 20 = 95%
      expect(detectDateFormat(['11/10/2026', 'oops']), isNull); // 50%
    });

    test('is null when there is nothing to go on', () {
      expect(detectDateFormat([]), isNull);
      expect(detectDateFormat(['', ' ']), isNull);
      expect(detectDateFormat(['hello', 'world']), isNull);
    });
  });
}
