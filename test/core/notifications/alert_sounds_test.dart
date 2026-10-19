import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';

void main() {
  group('the sound files', () {
    test('every kind has one in res/raw, and it is a short WAV', () {
      for (final kind in AlertKind.values) {
        final file = File('android/app/src/main/res/raw/${kind.sound}.wav');
        expect(file.existsSync(), isTrue, reason: kind.sound);
        final bytes = file.readAsBytesSync();
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
        // 22,050 samples a second, 2 bytes each: at most 3 seconds.
        expect(bytes.length, lessThan(22050 * 2 * 3 + 100), reason: kind.sound);
      }
    });

    test('are kept by the build, which finds them only by name', () {
      expect(
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
        contains('@raw/alert_*'),
      );
    });
  });

  group('the channel of a kind', () {
    test('plays the funny sound on its own channel', () {
      final fun = PluginReminderScheduler.detailsFor(
        AlertKind.budgetOver,
        funSounds: true,
      );

      expect(fun.channelId, 'budget_over_fun');
      expect(fun.sound?.sound, 'alert_wah');
      expect(fun.channelName, 'Budget crossed (funny sound)');
    });

    test('uses the usual phone sound without it', () {
      final plain = PluginReminderScheduler.detailsFor(
        AlertKind.budgetOver,
        funSounds: false,
      );

      expect(plain.channelId, 'budget_over');
      expect(plain.sound, isNull);
    });
  });

  test('a Reminder is a bill reminder unless it says otherwise', () {
    final reminder = Reminder(
      id: 1,
      title: 'Rent',
      body: 'Due',
      when: DateTime(2026, 11, 5, 9),
    );

    expect(reminder.kind, AlertKind.bill);
  });
}
