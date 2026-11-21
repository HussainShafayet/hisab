import 'package:drift/drift.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/debt_charge.dart';
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

  /// The expense of a transfer charge paid with this payment (the fee the
  /// bank or bKash took), if there was one. Not a foreign key: the entry may
  /// have been deleted by hand, and it goes with the payment otherwise.
  IntColumn get feeTransactionId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}

/// An amount added to what is owed on a loan I took: a late fee, interest or
/// another charge. When it also counted as my expense, [transactionId] is the
/// correction that cancels it on the account and [expenseId] the expense; both
/// go when the charge is deleted.
@DataClassName('DebtChargeRow')
class DebtCharges extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get debtId =>
      integer().references(Debts, #id, onDelete: KeyAction.cascade)();

  /// In poisha, above zero.
  IntColumn get amount => integer()();

  DateTimeColumn get chargedOn => dateTime()();

  TextColumn get kind => textEnum<DebtChargeKind>()();

  TextColumn get note => text().withDefault(const Constant(''))();

  IntColumn get transactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get expenseId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}
