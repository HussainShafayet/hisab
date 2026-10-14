import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Questions about how spending felt. Like every report, they leave out
/// balance adjustments.
extension FeelingQueries on AppDatabase {
  /// The money of the expenses in `start <= date < end` that were marked, by
  /// how they felt. A feeling nothing was marked with is not in the map.
  Future<Map<Feeling, int>> expenseByFeeling(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await customSelect(
      'SELECT feeling, SUM(amount) AS total FROM transactions '
      "WHERE type = '${TransactionType.expense.name}' AND is_adjustment = 0 "
      'AND feeling IS NOT NULL AND date >= ? AND date < ? GROUP BY feeling',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactions},
    ).get();
    return {
      for (final row in rows)
        Feeling.values.byName(row.read<String>('feeling')): row.read<int>(
          'total',
        ),
    };
  }

  /// How many expenses were marked with a feeling, ever.
  Future<int> markedExpenseCount() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM transactions '
      "WHERE type = '${TransactionType.expense.name}' AND is_adjustment = 0 "
      'AND feeling IS NOT NULL',
      readsFrom: {transactions},
    ).getSingle();
    return row.read<int>('n');
  }

  /// The local day of the latest expense marked as a regret, or null.
  Future<DateTime?> lastRegretDay() async {
    final row = await customSelect(
      'SELECT MAX(date) AS last FROM transactions '
      "WHERE type = '${TransactionType.expense.name}' AND is_adjustment = 0 "
      "AND feeling = '${Feeling.regret.name}'",
      readsFrom: {transactions},
    ).getSingle();
    final last = row.read<DateTime?>('last')?.toLocal();
    return last == null ? null : DateTime(last.year, last.month, last.day);
  }
}
