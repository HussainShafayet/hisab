import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/features/notifications/domain/logged_notification.dart';

/// Keeps the history of notifications: what the app showed, and what is on
/// the phone's schedule. It is written where the app tells the phone to show
/// or schedule something, since the phone does not tell the app when a
/// scheduled notification showed: one whose time has passed is taken as shown.
class NotificationLogRepository {
  NotificationLogRepository(this._db);

  final AppDatabase _db;

  Stream<List<LoggedNotification>> watchAll() => _db.notificationLogDao
      .watchAll()
      .map((rows) => rows.map(_toNotification).toList());

  /// [reminder] was shown right now.
  Future<void> recordShown(Reminder reminder, DateTime now) async {
    await _db.notificationLogDao.add(
      _companion(reminder, now, immediate: true),
    );
    await _prune(now);
  }

  /// [reminders] are now the whole schedule: what was set to show later and
  /// has not shown yet is replaced by them. What has already shown stays.
  Future<void> syncScheduled(List<Reminder> reminders, DateTime now) async {
    final dao = _db.notificationLogDao;
    await dao.deleteScheduledAfter(now);
    await dao.addAll([
      for (final reminder in reminders)
        if (reminder.when.isAfter(now)) _companion(reminder, reminder.when),
    ]);
    await _prune(now);
  }

  /// The notifications with these ids were taken off the schedule.
  Future<void> forgetScheduled(Iterable<int> notifIds, DateTime now) =>
      _db.notificationLogDao.deleteScheduledAfter(now, notifIds: notifIds);

  /// Empties the history of what has shown. What is still to come stays.
  Future<void> clearShown(DateTime now) =>
      _db.notificationLogDao.deleteShownBy(now);

  Future<void> _prune(DateTime now) => _db.notificationLogDao.prune(
    now,
    keep: maxKeptNotifications,
    oldest: now.subtract(const Duration(days: keptNotificationDays)),
  );

  NotificationLogCompanion _companion(
    Reminder reminder,
    DateTime at, {
    bool immediate = false,
  }) => NotificationLogCompanion.insert(
    notifId: reminder.id,
    kind: reminder.kind,
    title: reminder.title,
    body: reminder.body,
    at: at,
    immediate: Value(immediate),
  );

  LoggedNotification _toNotification(NotificationLogRow row) =>
      LoggedNotification(
        id: row.id,
        kind: row.kind,
        title: row.title,
        body: row.body,
        at: row.at,
        immediate: row.immediate,
      );
}
