import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/notifications/data/notification_log_table.dart';

part 'notification_log_dao.g.dart';

@DriftAccessor(tables: [NotificationLog])
class NotificationLogDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationLogDaoMixin {
  NotificationLogDao(super.attachedDatabase);

  Stream<List<NotificationLogRow>> watchAll() =>
      select(notificationLog).watch();

  Future<List<NotificationLogRow>> getAll() => select(notificationLog).get();

  Future<void> add(NotificationLogCompanion row) =>
      into(notificationLog).insert(row);

  Future<void> addAll(List<NotificationLogCompanion> rows) =>
      batch((batch) => batch.insertAll(notificationLog, rows));

  /// Takes away what was set to show after [now] on the phone's schedule.
  /// With [notifIds], only those notifications.
  Future<void> deleteScheduledAfter(DateTime now, {Iterable<int>? notifIds}) {
    return (delete(notificationLog)..where(
          (r) =>
              r.immediate.equals(false) &
              r.at.isBiggerThanValue(now) &
              (notifIds == null
                  ? const Constant(true)
                  : r.notifId.isIn(notifIds)),
        ))
        .go();
  }

  /// Deletes what has been shown by [now].
  Future<void> deleteShownBy(DateTime now) => (delete(
    notificationLog,
  )..where((r) => r.at.isSmallerOrEqualValue(now))).go();

  /// Keeps the newest [keep] shown notifications, and none from before
  /// [oldest].
  Future<void> prune(
    DateTime now, {
    required int keep,
    required DateTime oldest,
  }) async {
    await (delete(notificationLog)..where(
          (r) =>
              r.at.isSmallerOrEqualValue(now) & r.at.isSmallerThanValue(oldest),
        ))
        .go();
    final extra =
        await (select(notificationLog)
              ..where((r) => r.at.isSmallerOrEqualValue(now))
              ..orderBy([(r) => OrderingTerm.desc(r.at)])
              ..limit(1000, offset: keep))
            .get();
    if (extra.isEmpty) return;
    await (delete(
      notificationLog,
    )..where((r) => r.id.isIn(extra.map((row) => row.id)))).go();
  }
}
