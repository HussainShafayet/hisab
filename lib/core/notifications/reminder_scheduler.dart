import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_route.dart';
import 'package:hishab/core/notifications/alert_sound_mode.dart';
import 'package:timezone/timezone.dart' as tz;

/// A notification to show at [when] (local time).
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    this.kind = AlertKind.bill,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;

  /// Decides the channel and the sound.
  final AlertKind kind;
}

/// Puts reminders on the phone's notification schedule.
abstract class ReminderScheduler {
  /// Makes [reminders] the only scheduled ones: what was scheduled before is
  /// cancelled. Reminders in the past are ignored. With [funSounds] each kind
  /// plays its own funny sound; without, the phone's usual one.
  ///
  /// [overrides] are the sounds the person chose for single alerts; they win
  /// over [funSounds].
  Future<void> replaceAll(
    List<Reminder> reminders, {
    bool funSounds = true,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  });

  /// Shows [reminder] right now (its time is ignored), like the budget alert.
  Future<void> showNow(
    Reminder reminder, {
    bool funSounds = true,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  });

  /// Whether the phone lets Hishab show notifications right now.
  Future<bool> notificationsAllowed();

  /// Takes the notifications with these ids off the schedule.
  Future<void> cancel(Iterable<int> ids);

  /// Asks the person to allow notifications (Android 13 and later ask at run
  /// time). True when they are allowed.
  Future<bool> requestPermission();
}

/// Does nothing. What tests and screens that cannot show notifications use.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> replaceAll(
    List<Reminder> reminders, {
    bool funSounds = true,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  }) async {}

  @override
  Future<void> showNow(
    Reminder reminder, {
    bool funSounds = true,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  }) async {}

  @override
  Future<bool> notificationsAllowed() async => false;

  @override
  Future<void> cancel(Iterable<int> ids) async {}

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

  /// The channel of a kind: loud enough to show on screen, and with the kind's
  /// funny sound when [funSounds] is on.
  static AndroidNotificationDetails detailsFor(
    AlertKind kind, {
    required bool funSounds,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  }) {
    final mode = effectiveSound(
      kind,
      funSounds: funSounds,
      overrides: overrides,
    );
    switch (mode) {
      case AlertSoundMode.funny:
        return AndroidNotificationDetails(
          funnyChannelId(kind),
          tr('{name} (funny sound)', {'name': kind.label}),
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(kind.sound),
        );
      case AlertSoundMode.phone:
        return AndroidNotificationDetails(
          kind.channelId,
          kind.label,
          importance: Importance.high,
          priority: Priority.high,
        );
      case AlertSoundMode.silent:
        return AndroidNotificationDetails(
          silentChannelId(kind),
          tr('{name} (silent)', {'name': kind.label}),
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        );
    }
  }

  /// The channel with the funny sound. A channel keeps the sound it was made
  /// with for good, so a new name is the way to start afresh; the first one
  /// (`<id>_fun`) is deleted when the app starts.
  static String funnyChannelId(AlertKind kind) => '${kind.channelId}_fun2';

  /// The channel with no sound.
  static String silentChannelId(AlertKind kind) => '${kind.channelId}_silent';

  Future<void> _initialize() => _ready ??= _initializeNow();

  Future<void> _initializeNow() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // A tap on a notification opens the screen it is about.
      onDidReceiveNotificationResponse: (response) =>
          _openPayload(response.payload),
    );
    // The app was started by a tap on a notification.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _openPayload(launch!.notificationResponse?.payload);
    }
    // The one channel older versions made; each kind has its own now. And the
    // first funny-sound channels, which could keep a wrong sound for good.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.deleteNotificationChannel(channelId: 'recurring');
    for (final kind in AlertKind.values) {
      await android?.deleteNotificationChannel(
        channelId: '${kind.channelId}_fun',
      );
    }
  }

  static void _openPayload(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      pendingNotificationRoute.value = payload;
    }
  }

  @override
  Future<void> replaceAll(
    List<Reminder> reminders, {
    bool funSounds = true,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  }) async {
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
          notificationDetails: NotificationDetails(
            android: detailsFor(
              reminder.kind,
              funSounds: funSounds,
              overrides: overrides,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: routeForAlert(reminder.kind),
        );
      }
    } on Object catch (error) {
      // A reminder that cannot be scheduled must never break the app.
      debugPrint('Could not schedule reminders: $error');
    }
  }

  @override
  Future<void> showNow(
    Reminder reminder, {
    bool funSounds = true,
    Map<AlertKind, AlertSoundMode> overrides = const {},
  }) async {
    try {
      await _initialize();
      await _plugin.show(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        notificationDetails: NotificationDetails(
          android: detailsFor(
            reminder.kind,
            funSounds: funSounds,
            overrides: overrides,
          ),
        ),
        payload: routeForAlert(reminder.kind),
      );
    } on Object catch (error) {
      debugPrint('Could not show an alert: $error');
    }
  }

  @override
  Future<bool> notificationsAllowed() async {
    try {
      await _initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    } on Object catch (error) {
      debugPrint('Could not ask if notifications are on: $error');
      return false;
    }
  }

  @override
  Future<void> cancel(Iterable<int> ids) async {
    try {
      await _initialize();
      for (final id in ids) {
        await _plugin.cancel(id: id);
      }
    } on Object catch (error) {
      debugPrint('Could not cancel reminders: $error');
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
