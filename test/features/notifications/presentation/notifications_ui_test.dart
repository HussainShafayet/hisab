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

Future<void> openNotifications(WidgetTester tester) =>
    openFromMore(tester, 'Notifications');

Future<void> showTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('the notifications screen', () {
    testWithDatabase('opens from More and starts empty', (tester, db) async {
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
