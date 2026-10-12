import 'package:drift/drift.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/transactions/data/transactions_table.dart';

/// Money lent to or borrowed from a person. When an account was chosen, the
/// balance moved through an adjustment transaction ([transactionId]), which
/// the debt removes again when it is deleted.
@DataClassName('DebtRow')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get person => text().withLength(min: 1, max: 60)();

  TextColumn get direction => textEnum<DebtDirection>()();

  /// In poisha, above zero.
  IntColumn get amount => integer()();

  DateTimeColumn get openedOn => dateTime()();

  DateTimeColumn get dueOn => dateTime().nullable()();

  TextColumn get note => text().withDefault(const Constant(''))();

  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get transactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}

/// A part of a debt paid back.
@DataClassName('DebtPaymentRow')
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get debtId =>
      integer().references(Debts, #id, onDelete: KeyAction.cascade)();

  /// In poisha, above zero.
  IntColumn get amount => integer()();

  DateTimeColumn get paidOn => dateTime()();

  TextColumn get note => text().withDefault(const Constant(''))();

  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get transactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}
