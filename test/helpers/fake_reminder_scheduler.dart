import 'package:hishab/core/notifications/reminder_scheduler.dart';

/// Remembers what it was asked to schedule, for tests.
class FakeReminderScheduler implements ReminderScheduler {
  /// What was passed to the latest `replaceAll`.
  List<Reminder> scheduled = const [];
  int replaceCalls = 0;

  /// Whether the last `replaceAll` or `showNow` asked for funny sounds.
  bool funSounds = true;

  /// What was shown right away, in order.
  final shown = <Reminder>[];

  /// The ids that were taken off the schedule.
  final cancelled = <int>[];
  int permissionRequests = 0;
  bool allowed = true;

  @override
  Future<void> replaceAll(
    List<Reminder> reminders, {
    bool funSounds = true,
  }) async {
    scheduled = reminders;
    this.funSounds = funSounds;
    replaceCalls++;
  }

  @override
  Future<void> showNow(Reminder reminder, {bool funSounds = true}) async {
    shown.add(reminder);
    this.funSounds = funSounds;
  }

  @override
  Future<void> cancel(Iterable<int> ids) async => cancelled.addAll(ids);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }
}
