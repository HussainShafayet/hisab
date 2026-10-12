import 'package:drift/drift.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

/// Rows are never deleted, only archived (see [isArchived]), so old
/// transactions always keep a valid account.
@DataClassName('AccountRow')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get type => textEnum<AccountType>()();

  /// In poisha (1 BDT = 100 poisha). May be negative, e.g. a credit card.
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();

  /// A credit card only: the most it may owe, in poisha. Null when not set.
  IntColumn get creditLimit => integer().nullable()();

  /// A credit card only: the day of the month the bill is due, 1 to 31. In a
  /// shorter month it is the last day. Null when not set.
  IntColumn get billDueDay => integer().nullable()();

  BoolColumn get includeInTotal =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
