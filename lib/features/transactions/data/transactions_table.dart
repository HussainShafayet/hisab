import 'package:drift/drift.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/categories/data/categories_table.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
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

  /// True for the transaction that "Adjust balance" records to bring an
  /// account in line with reality. It changes the account's balance, but it is
  /// not real income or spending, so budgets and income/expense totals leave
  /// it out.
  BoolColumn get isAdjustment => boolean().withDefault(const Constant(false))();

  /// The trip or event (a row of `tags`) this income or expense belongs to,
  /// if any. Null for transfers. Not a foreign key, so the column can be added
  /// to an existing table; deleting a tag clears it here (see `TagsDao`).
  IntColumn get tagId => integer().nullable()();

  /// In US cents: the dollars behind a credit card entry. On an expense it is
  /// what was spent in dollars, on an income what was refunded in dollars, and
  /// on a transfer into the card what part of the payment cleared dollar
  /// spending. [amount] stays the taka the bank charged. Null when the entry
  /// has nothing to do with dollars.
  IntColumn get usdAmount => integer().nullable()();

  /// How an expense felt afterwards (needed, wanted, regret), if the person
  /// said. Null for income and transfers.
  TextColumn get feeling => textEnum<Feeling>().nullable()();

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
