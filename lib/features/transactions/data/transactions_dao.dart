import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/data/transactions_table.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
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
