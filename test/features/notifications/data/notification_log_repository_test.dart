import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/features/notifications/data/notification_log_repository.dart';
import 'package:hishab/features/notifications/domain/logged_notification.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

Reminder reminder(
  int id,
  DateTime when, {
  AlertKind kind = AlertKind.bill,
  String title = 'Bill due',
}) => Reminder(id: id, title: title, body: 'Body $id', when: when, kind: kind);

void main() {
  late AppDatabase db;
  late NotificationLogRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = NotificationLogRepository(db);
  });
  tearDown(() => db.close());

  Future<List<LoggedNotification>> all() => repo.watchAll().first;

  group('recordShown', () {
    test('keeps an alert as shown at the time it was sent', () async {
      await repo.recordShown(
        reminder(5, DateTime(2030), kind: AlertKind.budgetNear),
        now,
      );

      final rows = await all();
      expect(rows, hasLength(1));
      expect(rows.single.at, now);
      expect(rows.single.immediate, isTrue);
      expect(rows.single.kind, AlertKind.budgetNear);
      expect(rows.single.title, 'Bill due');
      expect(rows.single.body, 'Body 5');
    });
  });

  group('syncScheduled', () {
    test('keeps what is on the schedule, at the time it will show', () async {
      final when = DateTime(2026, 10, 12, 9);
      await repo.syncScheduled([reminder(1, when)], now);

      final rows = await all();
      expect(rows.single.at, when);
      expect(rows.single.immediate, isFalse);
    });

    test('leaves out a reminder whose time has passed', () async {
      await repo.syncScheduled([
        reminder(1, DateTime(2026, 10, 11, 9)),
        reminder(2, DateTime(2026, 10, 12, 9)),
      ], now);

      expect((await all()).map((n) => n.title), ['Bill due']);
      expect(await all(), hasLength(1));
    });

    test('replaces what was to come with the new schedule', () async {
      await repo.syncScheduled([
        reminder(1, DateTime(2026, 10, 12, 9), title: 'Old'),
      ], now);
      await repo.syncScheduled([
        reminder(2, DateTime(2026, 10, 13, 9), title: 'New'),
      ], now);

      expect((await all()).map((n) => n.title), ['New']);
    });

    test(
      'keeps what already showed, even when it is not on the new schedule',
      () async {
        final before = DateTime(2026, 10, 11, 9);
        await repo.syncScheduled([
          reminder(1, before, title: 'Shown'),
        ], before.subtract(const Duration(hours: 1)));

        await repo.syncScheduled([reminder(2, DateTime(2026, 10, 12, 9))], now);

        final titles = (await all()).map((n) => n.title).toList()..sort();
        expect(titles, ['Bill due', 'Shown']);
      },
    );

    test('keeps an alert that was shown right away', () async {
      await repo.recordShown(reminder(9, now, title: 'Alert'), now);

      await repo.syncScheduled(const [], now);

      expect((await all()).single.title, 'Alert');
    });
  });

  group('forgetScheduled', () {
    test('drops the reminders that were taken off the schedule', () async {
      await repo.syncScheduled([
        reminder(1, DateTime(2026, 10, 12, 9), title: 'Daily'),
        reminder(2, DateTime(2026, 10, 13, 9), title: 'Bill'),
      ], now);

      await repo.forgetScheduled([1], now);

      expect((await all()).map((n) => n.title), ['Bill']);
    });

    test('leaves one that already showed', () async {
      final before = DateTime(2026, 10, 11, 9);
      await repo.syncScheduled([
        reminder(1, before),
      ], before.subtract(const Duration(hours: 1)));

      await repo.forgetScheduled([1], now);

      expect(await all(), hasLength(1));
    });
  });

  group('clearShown', () {
    test('empties what showed and keeps what is coming', () async {
      await repo.recordShown(reminder(1, now, title: 'Alert'), now);
      await repo.syncScheduled([
        reminder(2, DateTime(2026, 10, 12, 9), title: 'Coming'),
      ], now);

      await repo.clearShown(now);

      expect((await all()).map((n) => n.title), ['Coming']);
    });
  });

  group('pruning', () {
    test('keeps only the newest $maxKeptNotifications shown', () async {
      for (var i = 0; i < maxKeptNotifications + 5; i++) {
        await repo.recordShown(
          reminder(i, now, title: 'No $i'),
          now.subtract(Duration(minutes: maxKeptNotifications + 5 - i)),
        );
      }

      final rows = await all();
      expect(rows, hasLength(maxKeptNotifications));
      // The five oldest are gone.
      expect(rows.any((n) => n.title == 'No 0'), isFalse);
      expect(rows.any((n) => n.title == 'No 5'), isTrue);
    });

    test('drops what is older than $keptNotificationDays days', () async {
      await repo.recordShown(
        reminder(1, now, title: 'Old'),
        now.subtract(const Duration(days: keptNotificationDays + 1)),
      );
      await repo.recordShown(reminder(2, now, title: 'Recent'), now);

      expect((await all()).map((n) => n.title), ['Recent']);
    });
  });

  group('seen', () {
    test('a new notification is not seen', () async {
      await repo.recordShown(reminder(1, now), now);
      await repo.syncScheduled([reminder(2, DateTime(2026, 10, 12, 9))], now);

      expect((await all()).every((n) => !n.seen), isTrue);
    });

    test('markSeen marks just that one', () async {
      await repo.recordShown(reminder(1, now, title: 'One'), now);
      await repo.recordShown(reminder(2, now, title: 'Two'), now);
      final first = (await all()).firstWhere((n) => n.title == 'One');

      await repo.markSeen(first.id);

      final byTitle = {for (final n in await all()) n.title: n.seen};
      expect(byTitle, {'One': true, 'Two': false});
    });

    test(
      'markAllSeen marks what has shown, not what is still to come',
      () async {
        await repo.recordShown(reminder(1, now, title: 'Shown'), now);
        await repo.syncScheduled([
          reminder(2, DateTime(2026, 10, 12, 9), title: 'Later'),
        ], now);

        await repo.markAllSeen(now);

        final byTitle = {for (final n in await all()) n.title: n.seen};
        expect(byTitle, {'Shown': true, 'Later': false});
      },
    );

    test('a reminder that is synced again keeps its place, unseen', () async {
      await repo.syncScheduled([
        reminder(1, DateTime(2026, 10, 12, 9), title: 'Later'),
      ], now);
      await repo.syncScheduled([
        reminder(1, DateTime(2026, 10, 12, 9), title: 'Later'),
      ], now);

      expect(await all(), hasLength(1));
    });
  });
}
