import 'package:drift/drift.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/transactions/data/transactions_table.dart';

/// Money put into a business or another venture. The money that went in and
/// came out is in [InvestmentEntries].
@DataClassName('InvestmentRow')
class Investments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get note => text().withDefault(const Constant(''))();

  DateTimeColumn get startedOn => dateTime()();

  /// What the money still in it is worth now, in poisha, as the person last
  /// set it. Null: not set, so it is taken to be worth what it cost.
  IntColumn get currentValue => integer().nullable()();

  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (current_value IS NULL OR current_value >= 0)',
  ];
}

/// A line of an investment. When an account was chosen, its balance moved
/// through a transaction ([transactionId]), which is removed again when the
/// line is deleted: money put in and taken back are corrections (not spending
/// and not income), profit is income.
@DataClassName('InvestmentEntryRow')
@TableIndex(
  name: 'idx_investment_entries_investment_id',
  columns: {#investmentId},
)
class InvestmentEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get investmentId =>
      integer().references(Investments, #id, onDelete: KeyAction.cascade)();

  TextColumn get kind => textEnum<InvestmentEntryKind>()();

  /// In poisha, above zero.
  IntColumn get amount => integer()();

  DateTimeColumn get date => dateTime()();

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
