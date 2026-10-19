import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The newest entry the person wrote.
class LatestEntry {
  const LatestEntry({
    required this.id,
    required this.isExpense,
    required this.categoryId,
  });

  final int id;
  final bool isExpense;
  final int? categoryId;
}

/// What the alerts need to know about the entries.
extension AlertQueries on AppDatabase {
  /// The entry with the highest id (balance adjustments left out), or null
  /// when there is none.
  Future<LatestEntry?> latestEntry() async {
    final rows = await customSelect(
      'SELECT id, type, category_id FROM transactions '
      'WHERE is_adjustment = 0 ORDER BY id DESC LIMIT 1',
      readsFrom: {transactions},
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    return LatestEntry(
      id: row.read<int>('id'),
      isExpense: row.read<String>('type') == TransactionType.expense.name,
      categoryId: row.readNullable<int>('category_id'),
    );
  }

  /// How many expenses of [categoryId] were written on or after [since], and
  /// how much they came to (poisha).
  Future<({int count, int total})> expensesSince(
    int categoryId,
    DateTime since,
  ) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total '
      'FROM transactions WHERE is_adjustment = 0 AND type = ? '
      'AND category_id = ? AND date >= ?',
      variables: [
        Variable.withString(TransactionType.expense.name),
        Variable.withInt(categoryId),
        Variable.withDateTime(since),
      ],
      readsFrom: {transactions},
    ).getSingle();
    return (count: row.read<int>('n'), total: row.read<int>('total'));
  }

  /// The name of a category, or null when it is gone.
  Future<String?> categoryNameOf(int categoryId) async {
    final rows = await customSelect(
      'SELECT name FROM categories WHERE id = ?',
      variables: [Variable.withInt(categoryId)],
      readsFrom: {categories},
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('name');
  }
}
