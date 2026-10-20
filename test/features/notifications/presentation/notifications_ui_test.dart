import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/features/notifications/data/notification_log_repository.dart';

import '../../../helpers/pump_app.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
final now = DateTime(2026, 10, 11, 14, 30);

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Reminder reminder(int id, String title, DateTime when, {AlertKind? kind}) =>
    Reminder(
      id: id,
      title: title,
      body: 'Body of $title',
      when: when,
      kind: kind ?? AlertKind.bill,
    );

Future<void> openNotifications(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('notification-bell')));
  await tester.pumpAndSettle();
}

int? badgeCount(WidgetTester tester) {
  final badge = tester.widget<Badge>(
    find.byKey(const ValueKey('notification-badge')),
  );
  if (!badge.isLabelVisible) return null;
  return int.parse((badge.label! as Text).data!);
}

Future<void> showTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('the notifications screen', () {
    testWithDatabase('opens from the bell and starts empty', (
      tester,
      db,
    ) async {
      await pumpAppWithDatabase(tester, db);

      await openNotifications(tester);

      expect(appBarTitle('Notifications'), findsOneWidget);
      expect(find.text('Nothing sent yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-notifications')), findsNothing);

      await showTab(tester, 'tab-upcoming');
      expect(find.text('Nothing coming up'), findsOneWidget);
    });

    testWithDatabase('lists what was sent, newest first, by day', (
      tester,
      db,
    ) async {
      final repo = NotificationLogRepository(db);
      await repo.recordShown(
        reminder(1, 'Budget almost used', now, kind: AlertKind.budgetNear),
        DateTime(2026, 10, 10, 20, 15),
      );
      await repo.recordShown(
        reminder(2, 'Habit alert', now, kind: AlertKind.habit),
        DateTime(2026, 10, 11, 9, 5),
      );
      await pumpAppWithDatabase(tester, db);

      await openNotifications(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('9:05 AM'), findsOneWidget);
      expect(find.text('8:15 PM'), findsOneWidget);
      final habit = tester.getTopLeft(find.text('Habit alert')).dy;
      final budget = tester.getTopLeft(find.text('Budget almost used')).dy;
      expect(habit, lessThan(budget));
      expect(find.byKey(const ValueKey('clear-notifications')), findsOneWidget);
    });

    testWithDatabase('lists what is coming up, the soonest first', (
      tester,
      db,
    ) async {
      // The app puts its own reminders on the list when it starts, so the
      // daily reminder (9 pm each evening) is the source here.
      await db.settingsDao.put('daily_reminder', 'true');
      await pumpAppWithDatabase(tester, db);

      await openNotifications(tester);
      await showTab(tester, 'tab-upcoming');

      expect(find.text('Takka is waiting'), findsWidgets);
      expect(find.text('9:00 PM'), findsWidgets);
      final today = tester.getTopLeft(find.text('Today')).dy;
      final tomorrow = tester.getTopLeft(find.text('Mon, 12 Oct')).dy;
      expect(today, lessThan(tomorrow));
      // They have not come yet, so they are not in the sent list.
      await showTab(tester, 'tab-sent');
      expect(find.text('Nothing sent yet'), findsOneWidget);
    });

    testWithDatabase('clears the sent ones only after asking', (
      tester,
      db,
    ) async {
      await NotificationLogRepository(db)
          .recordShown(reminder(1, 'Habit alert', now), now);
      await db.settingsDao.put('daily_reminder', 'true');
      await pumpAppWithDatabase(tester, db);
      await openNotifications(tester);

      // Backing out keeps everything.
      await tester.tap(find.byKey(const ValueKey('clear-notifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Habit alert'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('clear-notifications')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-clear-notifications')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Habit alert'), findsNothing);
      expect(find.text('Nothing sent yet'), findsOneWidget);
      expect(find.text('History cleared'), findsOneWidget);
      await showTab(tester, 'tab-upcoming');
      expect(find.text('Takka is waiting'), findsWidgets);
    });
  });

  group('seen and unseen', () {
    Reminder note(int id, String title) => reminder(id, title, now);

    testWithDatabase('the bell counts what has not been opened', (
      tester,
      db,
    ) async {
      final repo = NotificationLogRepository(db);
      await pumpAppWithDatabase(tester, db);
      expect(badgeCount(tester), isNull);

      await repo.recordShown(note(1, 'One'), now);
      await repo.recordShown(note(2, 'Two'), now);
      await tester.pumpAndSettle();

      expect(badgeCount(tester), 2);
    });

    testWithDatabase('a notification still to come is not counted', (
      tester,
      db,
    ) async {
      await db.settingsDao.put('daily_reminder', 'true');
      await pumpAppWithDatabase(tester, db);

      expect(badgeCount(tester), isNull);
    });

    testWithDatabase(
      'unseen ones are marked, and opening one clears its mark',
      (tester, db) async {
        final repo = NotificationLogRepository(db);
        await repo.recordShown(note(1, 'Budget almost used'), now);
        await repo.recordShown(note(2, 'Habit alert'), now);
        await pumpAppWithDatabase(tester, db);
        expect(badgeCount(tester), 2);

        await openNotifications(tester);
        final ids = [
          for (final r in await db.notificationLogDao.getAll()) r.id,
        ];
        for (final id in ids) {
          expect(find.byKey(ValueKey('unseen-dot-$id')), findsOneWidget);
        }

        await tester.tap(find.byKey(ValueKey('notification-${ids.first}')));
        await tester.pumpAndSettle();

        final rows = {
          for (final r in await db.notificationLogDao.getAll()) r.id: r.seen,
        };
        expect(rows[ids.first], isTrue);
        expect(rows[ids.last], isFalse);
      },
    );

    testWithDatabase('the double tick marks them all as read', (
      tester,
      db,
    ) async {
      final repo = NotificationLogRepository(db);
      await repo.recordShown(note(1, 'One'), now);
      await repo.recordShown(note(2, 'Two'), now);
      await pumpAppWithDatabase(tester, db);
      await openNotifications(tester);

      await tester.tap(find.byKey(const ValueKey('mark-all-read')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mark-all-read')), findsNothing);
      expect(
        (await db.notificationLogDao.getAll()).every((r) => r.seen),
        isTrue,
      );
      // Back on Home, the bell has no number.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(badgeCount(tester), isNull);
    });

    testWithDatabase('the bell is on each of the main tabs', (
      tester,
      db,
    ) async {
      await pumpAppWithDatabase(tester, db);
      for (final tab in ['Home', 'Transactions', 'Budget', 'Reports', 'More']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('notification-bell')),
          findsOneWidget,
          reason: tab,
        );
      }
    });

    testWithDatabase('More no longer has a Notifications row', (
      tester,
      db,
    ) async {
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
    });
  });

  group('the history while the app runs', () {
    testWithDatabase('lists the daily reminder before its time', (
      tester,
      db,
    ) async {
      await db.settingsDao.put('daily_reminder', 'true');
      await pumpAppWithDatabase(tester, db);

      final logged = await db.notificationLogDao.getAll();

      expect(
        logged.where((r) => !r.immediate).map((r) => r.kind),
        contains(AlertKind.daily),
      );
    });
  });
}
