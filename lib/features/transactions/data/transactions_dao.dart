import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/categories/data/categories_table.dart';
import 'package:hishab/features/transactions/data/transactions_table.dart';
import 'package:hishab/features/transactions/domain/category_usage.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

part 'transactions_dao.g.dart';

/// A transaction row with the rows it points to, read in one query.
typedef TransactionWithDetails = ({
  TransactionRow transaction,
  AccountRow account,
  AccountRow? toAccount,
  CategoryRow? category,
});

@DriftAccessor(tables: [Transactions, Accounts, Categories])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.attachedDatabase);

  Future<TransactionRow?> getById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Transactions with `start <= date < end`, newest first. Compute [start]
  /// and [end] in local time (e.g. first day of this month and of the next).
  Stream<List<TransactionRow>> watchBetween(DateTime start, DateTime end) =>
      _selectBetween(start, end).watch();

  Future<List<TransactionRow>> getBetween(DateTime start, DateTime end) =>
      _selectBetween(start, end).get();

  SimpleSelectStatement<$TransactionsTable, TransactionRow> _selectBetween(
    DateTime start,
    DateTime end,
  ) {
    return select(transactions)
      ..where(
        (t) =>
            t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ]);
  }

  /// Like [watchBetween], with the accounts and category of every row.
  Stream<List<TransactionWithDetails>> watchBetweenWithDetails(
    DateTime start,
    DateTime end,
  ) => _selectWithDetails(
    (t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end),
  ).watch();

  Future<TransactionWithDetails?> getWithDetails(int id) =>
      _selectWithDetails((t) => t.id.equals(id)).getSingleOrNull();

  /// The biggest expenses with `start <= date < end`, biggest first, at most
  /// [limit]. Transfers and balance adjustments are not expenses.
  Future<List<TransactionWithDetails>> topExpensesWithDetails(
    DateTime start,
    DateTime end, {
    required int limit,
  }) => _selectWithDetails(
    (t) =>
        t.type.equalsValue(TransactionType.expense) &
        t.isAdjustment.equals(false) &
        t.date.isBiggerOrEqualValue(start) &
        t.date.isSmallerThanValue(end),
    orderBy: [
      OrderingTerm.desc(transactions.amount),
      OrderingTerm.desc(transactions.date),
      OrderingTerm.desc(transactions.id),
    ],
    limit: limit,
  ).get();

  /// The latest transactions of any kind, newest first, at most [limit].
  Future<List<TransactionWithDetails>> latestWithDetails({
    required int limit,
  }) => _selectWithDetails((t) => const Constant(true), limit: limit).get();

  /// Joined rows in [orderBy] (newest first by default), at most [limit].
  Selectable<TransactionWithDetails> _selectWithDetails(
    Expression<bool> Function($TransactionsTable t) where, {
    List<OrderingTerm>? orderBy,
    int? limit,
  }) {
    final from = alias(accounts, 'from_account');
    final to = alias(accounts, 'to_account');
    final query =
        select(transactions).join([
            innerJoin(from, from.id.equalsExp(transactions.accountId)),
            leftOuterJoin(to, to.id.equalsExp(transactions.toAccountId)),
            leftOuterJoin(
              categories,
              categories.id.equalsExp(transactions.categoryId),
            ),
          ])
          ..where(where(transactions))
          ..orderBy(
            orderBy ??
                [
                  OrderingTerm.desc(transactions.date),
                  OrderingTerm.desc(transactions.id),
                ],
          );
    if (limit != null) query.limit(limit);

    return query.map(
      (row) => (
        transaction: row.readTable(transactions),
        account: row.readTable(from),
        toAccount: row.readTableOrNull(to),
        category: row.readTableOrNull(categories),
      ),
    );
  }

  /// How often each category of [type] was used since [since], for ordering
  /// the quick-pick chips. Categories never used are not in the result.
  Future<Map<int, CategoryUsage>> categoryUsage(
    TransactionType type, {
    required DateTime since,
  }) async {
    final rows = await customSelect(
      'SELECT category_id, COUNT(*) AS uses, MAX(date) AS last_used '
      'FROM transactions '
      'WHERE type = ? AND category_id IS NOT NULL AND date >= ? '
      'GROUP BY category_id',
      variables: [Variable.withString(type.name), Variable.withDateTime(since)],
      readsFrom: {transactions},
    ).get();

    return {
      for (final row in rows)
        row.read<int>('category_id'): CategoryUsage(
          count: row.read<int>('uses'),
          lastUsed: row.read<DateTime>('last_used'),
        ),
    };
  }

  /// The account of the transaction that was saved last, or null if there are
  /// no transactions.
  Future<int?> lastUsedAccountId() async {
    final latest =
        await (select(transactions)
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    return latest?.accountId;
  }

  /// Returns the new id.
  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction);

  /// Replaces the whole row and refreshes `updatedAt`. Returns false if the
  /// id does not exist.
  Future<bool> updateTransaction(TransactionRow transaction) =>
      update(transactions)
          .replace(transaction.copyWith(updatedAt: DateTime.now()));

  /// Hard delete. To undo, insert the same row again (same id) with
  /// `row.toCompanion(true)`.
  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();
}
