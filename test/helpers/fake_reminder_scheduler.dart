import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_sound_mode.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';

/// Remembers what it was asked to schedule, for tests.
class FakeReminderScheduler implements ReminderScheduler {
  /// What was passed to the latest `replaceAll`.
  List<Reminder> scheduled = const [];
  int replaceCalls = 0;

  /// Whether the last `replaceAll` or `showNow` asked for funny sounds.
  bool funSounds = true;

  /// The sounds chosen for single alerts, as of the last call.
  Map<AlertKind, AlertSoundMode> overrides = const {};

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
    Map<AlertKind, AlertSoundMode> overrides = const {},
  }) async {
    scheduled = reminders;
    this.funSounds = funSounds;
    this.overrides = overrides;
    replaceCalls++;
  }

  @override
  Future<void> showNow(
    Reminder reminder, {
    bool funSounds = true,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  }) async {
    shown.add(reminder);
    this.funSounds = funSounds;
    this.overrides = overrides;
  }

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<void> cancel(Iterable<int> ids) async => cancelled.addAll(ids);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }
}
