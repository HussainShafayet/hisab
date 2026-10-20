import 'package:drift/drift.dart';
import 'package:hishab/core/notifications/alert_kind.dart';

/// What the app has shown or has set to show: the history behind
/// the notification bell. A row is a notification of the kind [kind] that
/// showed (or will show) at [at]. Those with [immediate] were shown by the app
/// at that moment (budget and habit alerts); the others were put on the
/// phone's schedule and show around their time.
@DataClassName('NotificationLogRow')
@TableIndex(name: 'idx_notification_log_at', columns: {#at})
class NotificationLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The id the notification has on the phone.
  IntColumn get notifId => integer()();

  TextColumn get kind => textEnum<AlertKind>()();

  TextColumn get title => text()();

  TextColumn get body => text()();

  DateTimeColumn get at => dateTime()();

  BoolColumn get immediate => boolean().withDefault(const Constant(false))();

  /// The person has opened it from the bell. A new one is not seen.
  BoolColumn get seen => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
