import 'package:hishab/core/notifications/alert_kind.dart';

/// A notification in the history: shown at [at], or due to show then.
class LoggedNotification {
  const LoggedNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.immediate,
    this.seen = false,
  });

  final int id;
  final AlertKind kind;
  final String title;
  final String body;
  final DateTime at;

  /// Shown by the app at [at], not put on the phone's schedule.
  final bool immediate;

  /// The person has opened it from the bell.
  final bool seen;
}

/// How many notifications have shown by [now] and have not been seen.
int unseenCount(Iterable<LoggedNotification> all, DateTime now) =>
    all.where((n) => !n.seen && !n.at.isAfter(now)).length;

/// The history split at [now].
typedef NotificationLists = ({
  List<LoggedNotification> sent,
  List<LoggedNotification> upcoming,
});

/// The ones that have shown (newest first) and the ones still to come (the
/// soonest first). One at exactly [now] counts as shown.
NotificationLists splitNotifications(
  Iterable<LoggedNotification> all,
  DateTime now,
) {
  final sent = all.where((n) => !n.at.isAfter(now)).toList()
    ..sort((a, b) => b.at.compareTo(a.at));
  final upcoming = all.where((n) => n.at.isAfter(now)).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return (sent: sent, upcoming: upcoming);
}

/// How many shown notifications are kept, and for how long.
const maxKeptNotifications = 200;
const keptNotificationDays = 90;
