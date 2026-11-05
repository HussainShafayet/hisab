import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_sound_mode.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';

void main() {
  test('each alert has its own setting', () {
    expect(alertSoundKey(AlertKind.bill), 'sound_bill');
    expect(alertSoundKey(AlertKind.budgetOver), 'sound_budget_over');
  });

  test('reads the sounds the person chose and ignores the rest', () {
    final overrides = alertSoundOverrides({
      'sound_bill': 'silent',
      'sound_loan': 'phone',
      'sound_daily': 'rubbish',
      'fun_sounds': 'true',
    });
    expect(overrides, {
      AlertKind.bill: AlertSoundMode.silent,
      AlertKind.loan: AlertSoundMode.phone,
    });
  });

  group('effectiveSound', () {
    test('without a choice the general switch counts', () {
      expect(
        effectiveSound(AlertKind.bill, funSounds: true),
        AlertSoundMode.funny,
      );
      expect(
        effectiveSound(AlertKind.bill, funSounds: false),
        AlertSoundMode.phone,
      );
    });

    test('its own choice wins', () {
      expect(
        effectiveSound(
          AlertKind.bill,
          funSounds: true,
          overrides: {AlertKind.bill: AlertSoundMode.silent},
        ),
        AlertSoundMode.silent,
      );
      expect(
        effectiveSound(
          AlertKind.loan,
          funSounds: false,
          overrides: {AlertKind.bill: AlertSoundMode.silent},
        ),
        AlertSoundMode.phone,
      );
    });
  });

  group('the channel of a chosen sound', () {
    test('funny has its own sound on a fresh channel', () {
      final details = PluginReminderScheduler.detailsFor(
        AlertKind.zakat,
        funSounds: false,
        overrides: {AlertKind.zakat: AlertSoundMode.funny},
      );
      expect(details.channelId, 'zakat_fun2');
      expect(details.sound?.sound, 'alert_chime');
    });

    test("phone's uses the usual channel and sound", () {
      final details = PluginReminderScheduler.detailsFor(
        AlertKind.zakat,
        funSounds: true,
        overrides: {AlertKind.zakat: AlertSoundMode.phone},
      );
      expect(details.channelId, 'zakat');
      expect(details.sound, isNull);
    });

    test('silent makes no sound and no buzz', () {
      final details = PluginReminderScheduler.detailsFor(
        AlertKind.zakat,
        funSounds: true,
        overrides: {AlertKind.zakat: AlertSoundMode.silent},
      );
      expect(details.channelId, 'zakat_silent');
      expect(details.playSound, isFalse);
      expect(details.enableVibration, isFalse);
    });
  });
}
