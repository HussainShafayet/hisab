import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';

void main() {
  group('NoopReminderScheduler', () {
    test('accepts reminders and does nothing', () async {
      const scheduler = NoopReminderScheduler();

      await scheduler.replaceAll([
        Reminder(
          id: 1,
          title: 'Rent',
          body: '৳15,000.00 is due today.',
          when: DateTime(2026, 11, 5, 9),
        ),
      ]);
    });

    test('says notifications are allowed', () async {
      expect(await const NoopReminderScheduler().requestPermission(), isTrue);
    });
  });

  test('a Reminder keeps what it was given', () {
    final when = DateTime(2026, 11, 5, 9);
    final reminder = Reminder(id: 12, title: 'Rent', body: 'Due', when: when);

    expect(reminder.id, 12);
    expect(reminder.title, 'Rent');
    expect(reminder.body, 'Due');
    expect(reminder.when, when);
  });
}
