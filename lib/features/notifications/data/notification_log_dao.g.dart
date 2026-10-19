// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_log_dao.dart';

// ignore_for_file: type=lint
mixin _$NotificationLogDaoMixin on DatabaseAccessor<AppDatabase> {
  $NotificationLogTable get notificationLog => attachedDatabase.notificationLog;
  NotificationLogDaoManager get managers => NotificationLogDaoManager(this);
}

class NotificationLogDaoManager {
  final _$NotificationLogDaoMixin _db;
  NotificationLogDaoManager(this._db);
  $$NotificationLogTableTableManager get notificationLog =>
      $$NotificationLogTableTableManager(
        _db.attachedDatabase,
        _db.notificationLog,
      );
}
