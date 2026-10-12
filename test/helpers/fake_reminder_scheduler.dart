import 'package:hishab/core/notifications/reminder_scheduler.dart';

/// Remembers what it was asked to schedule, for tests.
class FakeReminderScheduler implements ReminderScheduler {
  /// What was passed to the latest `replaceAll`.
  List<Reminder> scheduled = const [];
  int replaceCalls = 0;
  int permissionRequests = 0;
  bool allowed = true;

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    scheduled = reminders;
    replaceCalls++;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }
}
