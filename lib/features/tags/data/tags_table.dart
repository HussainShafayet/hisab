import 'package:drift/drift.dart';

/// A trip or event that transactions can be tagged with, like "Cox's Bazar"
/// or "Eid", to see what it cost in all.
@DataClassName('TagRow')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 40)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
