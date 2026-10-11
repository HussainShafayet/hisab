import 'package:drift/drift.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/categories/data/categories_table.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

@DataClassName('TransactionRow')
@TableIndex(name: 'idx_transactions_date', columns: {#date})
@TableIndex(name: 'idx_transactions_account_id', columns: {#accountId})
@TableIndex(name: 'idx_transactions_to_account_id', columns: {#toAccountId})
@TableIndex(name: 'idx_transactions_category_id', columns: {#categoryId})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get type => textEnum<TransactionType>()();

  /// In poisha, always positive. The sign comes from [type].
  IntColumn get amount => integer()();

  /// The account money leaves (expense, transfer) or arrives in (income).
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();

  /// Transfers only: the account that receives the money.
  @ReferenceName('incomingTransfers')
  IntColumn get toAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Required for income and expense, must be null for transfers.
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// A point in time, stored as UTC. Group by day or month using the local
  /// time zone (`date.toLocal()`), never the UTC date.
  DateTimeColumn get date => dateTime()();

  TextColumn get note => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // drift needs literal strings here, so 'transfer' is spelled out instead of
  // using TransactionType.transfer.name (a test guards against drift).
  @override
  List<String> get customConstraints => [
    'CHECK (amount > 0)',
    '''
CHECK (
  (type = 'transfer'
    AND to_account_id IS NOT NULL
    AND to_account_id <> account_id
    AND category_id IS NULL)
  OR
  (type <> 'transfer'
    AND to_account_id IS NULL
    AND category_id IS NOT NULL)
)''',
  ];
}
