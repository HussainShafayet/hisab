import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_sound_mode.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';

import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/pump_app.dart';

Future<FakeReminderScheduler> openAlertSounds(
  WidgetTester tester,
  dynamic db, {
  bool allowed = true,
}) async {
  useTallScreen(tester);
  final scheduler = FakeReminderScheduler()..allowed = allowed;
  await pumpAppWithDatabase(
    tester,
    db,
    overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
  );
  await openFromMore(tester, 'Settings');
  final tile = find.byKey(const ValueKey('alert-sounds'));
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  return scheduler;
}

void main() {
  group('the Alert sounds screen', () {
    testWithDatabase('says notifications are allowed', (tester, db) async {
      await openAlertSounds(tester, db);

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('alerts-status-text')))
            .data,
        'Notifications are allowed.',
      );
      expect(find.byKey(const ValueKey('alerts-allow')), findsNothing);
    });

    testWithDatabase('offers to allow them when they are off', (
      tester,
      db,
    ) async {
      final scheduler = await openAlertSounds(tester, db, allowed: false);

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('alerts-status-text')))
            .data,
        'Notifications are off for Hishab.',
      );
      await tester.tap(find.byKey(const ValueKey('alerts-allow')));
      await tester.pumpAndSettle();
      expect(scheduler.permissionRequests, 1);
    });

    testWithDatabase('chooses a sound for one alert and keeps it', (
      tester,
      db,
    ) async {
      await openAlertSounds(tester, db);

      final bill = find.byKey(const ValueKey('alert-mode-bill'));
      await tester.ensureVisible(bill);
      await tester.tap(
        find.descendant(of: bill, matching: find.text('Silent')),
      );
      await tester.pumpAndSettle();

      expect((await db.settingsDao.getAll())['sound_bill'], 'silent');
      expect(tester.widget<SegmentedButton<AlertSoundMode>>(bill).selected, {
        AlertSoundMode.silent,
      });
      // The others stay on the general choice (funny).
      expect(
        tester
            .widget<SegmentedButton<AlertSoundMode>>(
              find.byKey(const ValueKey('alert-mode-loan')),
            )
            .selected,
        {AlertSoundMode.funny},
      );
    });

    testWithDatabase('Hear it shows the alert with the chosen sound', (
      tester,
      db,
    ) async {
      final scheduler = await openAlertSounds(tester, db);
      final bill = find.byKey(const ValueKey('alert-mode-bill'));
      await tester.ensureVisible(bill);
      await tester.tap(
        find.descendant(of: bill, matching: find.text("Phone's")),
      );
      await tester.pumpAndSettle();

      final test = find.byKey(const ValueKey('alert-test-bill'));
      await tester.ensureVisible(test);
      await tester.tap(test);
      await tester.pumpAndSettle();

      expect(scheduler.shown.single.kind, AlertKind.bill);
      expect(scheduler.overrides[AlertKind.bill], AlertSoundMode.phone);
    });

    testWithDatabase('Hear it says so when notifications are off', (
      tester,
      db,
    ) async {
      final scheduler = await openAlertSounds(tester, db, allowed: false);

      final test = find.byKey(const ValueKey('alert-test-bill'));
      await tester.ensureVisible(test);
      await tester.tap(test);
      await tester.pumpAndSettle();

      expect(scheduler.shown, isEmpty);
      expect(
        find.textContaining('Notifications are off for Hishab. Turn'),
        findsOneWidget,
      );
    });

    testWithDatabase('the choices can all be put back', (tester, db) async {
      await openAlertSounds(tester, db);
      final bill = find.byKey(const ValueKey('alert-mode-bill'));
      await tester.ensureVisible(bill);
      await tester.tap(
        find.descendant(of: bill, matching: find.text('Silent')),
      );
      await tester.pumpAndSettle();

      final reset = find.byKey(const ValueKey('alerts-reset'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect((await db.settingsDao.getAll())['sound_bill'], isNull);
      expect(find.byKey(const ValueKey('alerts-reset')), findsNothing);
    });
  });
}
