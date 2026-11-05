import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/settings/domain/more_status.dart';

void main() {
  group('backupStatus', () {
    test('never made is a warning', () {
      final status = backupStatus(null);
      expect(status.kind, MoreStatusKind.backupNever);
      expect(status.warning, isTrue);
    });

    test('two weeks old is a warning, a recent one is not', () {
      expect(backupStatus(14).kind, MoreStatusKind.backupOld);
      expect(backupStatus(14).warning, isTrue);
      expect(backupStatus(13).kind, MoreStatusKind.backupFresh);
      expect(backupStatus(13).warning, isFalse);
    });
  });

  test('loans show only when some are late', () {
    expect(loansStatus(0), isNull);
    expect(loansStatus(2)!.args['count'], 2);
    expect(loansStatus(2)!.warning, isTrue);
  });

  test('a recurring item shows when it is within three days', () {
    expect(recurringStatus(null), isNull);
    expect(recurringStatus(-1), isNull);
    expect(recurringStatus(0)!.args['days'], 0);
    expect(recurringStatus(3)!.args['days'], 3);
    expect(recurringStatus(4), isNull);
  });

  group('the recent places', () {
    test('the newest goes first and a repeat moves up', () {
      var recent = <String>[];
      recent = rememberVisit(recent, '/more/debts');
      recent = rememberVisit(recent, '/more/zakat');
      recent = rememberVisit(recent, '/more/debts');
      expect(recent, ['/more/debts', '/more/zakat']);
    });

    test('only the last four are kept', () {
      var recent = <String>[];
      for (final route in ['/a', '/b', '/c', '/d', '/e']) {
        recent = rememberVisit(recent, route);
      }
      expect(recent, ['/e', '/d', '/c', '/b']);
    });

    test(
      'a saved list is read back, ignoring anything that is not a route',
      () {
        expect(parseRecent('/more/debts,/more/zakat'), [
          '/more/debts',
          '/more/zakat',
        ]);
        expect(parseRecent('junk,/more/goals,'), ['/more/goals']);
        expect(parseRecent(null), isEmpty);
      },
    );
  });
}
