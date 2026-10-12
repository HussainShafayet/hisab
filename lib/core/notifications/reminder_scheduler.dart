import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// A notification to show at [when] (local time).
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
}

/// Puts reminders on the phone's notification schedule.
abstract class ReminderScheduler {
  /// Makes [reminders] the only scheduled ones: what was scheduled before is
  /// cancelled. Reminders in the past are ignored.
  Future<void> replaceAll(List<Reminder> reminders);

  /// Asks the person to allow notifications (Android 13 and later ask at run
  /// time). True when they are allowed.
  Future<bool> requestPermission();
}

/// Does nothing. What tests and screens that cannot show notifications use.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {}

  @override
  Future<bool> requestPermission() async => true;
}

/// The reminder scheduler of the app. `main()` replaces it with the real
/// one, so tests never touch the notification plugin.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => const NoopReminderScheduler(),
);

/// Schedules local notifications with `flutter_local_notifications`. A
/// reminder is shown around its time, not to the second (inexact alarms), so
/// the app needs no special alarm permission.
class PluginReminderScheduler implements ReminderScheduler {
  PluginReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _channel = AndroidNotificationDetails(
    'recurring',
    'Recurring transactions',
    channelDescription: 'Reminders for bills and income that repeat',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _initialize() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    try {
      await _initialize();
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final reminder in reminders) {
        if (!reminder.when.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          // An exact moment in time, whatever the time zone database says.
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.UTC,
            reminder.when.millisecondsSinceEpoch,
          ),
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object catch (error) {
      // A reminder that cannot be scheduled must never break the app.
      debugPrint('Could not schedule reminders: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } on Object catch (error) {
      debugPrint('Could not ask for notification permission: $error');
      return false;
    }
  }
}
