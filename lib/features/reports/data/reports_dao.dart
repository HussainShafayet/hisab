import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/data/transactions_table.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

part 'reports_dao.g.dart';

/// Spending of one top-level category.
typedef CategoryTotalRow = ({
  int categoryId,
  String name,
  String icon,
  int color,
  int total,
});

/// Sums for reports. Every query leaves out transfers (they only move money
/// between accounts) and balance adjustments (corrections, not real income or
/// spending), so all screens agree on what "income" and "expense" are.
///
/// Ranges are `start <= date < end` in local time.
@DriftAccessor(tables: [Transactions])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(super.attachedDatabase);

  Future<({int income, int expense})> incomeExpenseTotals(
    DateTime start,
    DateTime end,
  ) async {
    // The type names come from our own enum, never from user input.
    final income = TransactionType.income.name;
    final expense = TransactionType.expense.name;
    final row = await customSelect(
      'SELECT '
      "COALESCE(SUM(CASE WHEN type = '$income' THEN amount END), 0) AS income, "
      "COALESCE(SUM(CASE WHEN type = '$expense' THEN amount END), 0) AS expense "
      'FROM transactions '
      'WHERE date >= ? AND date < ? AND is_adjustment = 0 '
      "AND type IN ('$income', '$expense')",
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactions},
    ).getSingle();
    return (income: row.read<int>('income'), expense: row.read<int>('expense'));
  }

  /// Expenses grouped by top-level category, biggest first. A sub-category's
  /// spending counts for its parent.
  Future<List<CategoryTotalRow>> expenseByCategory(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await customSelect(
      'SELECT p.id AS category_id, p.name AS name, p.icon AS icon, '
      'p.color AS color, SUM(t.amount) AS total '
      'FROM transactions t '
      'JOIN categories c ON c.id = t.category_id '
      'JOIN categories p ON p.id = COALESCE(c.parent_id, c.id) '
      "WHERE t.type = '${TransactionType.expense.name}' "
      'AND t.is_adjustment = 0 AND t.date >= ? AND t.date < ? '
      'GROUP BY p.id ORDER BY total DESC, p.id',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactions, attachedDatabase.categories},
    ).get();
    return [
      for (final row in rows)
        (
          categoryId: row.read<int>('category_id'),
          name: row.read<String>('name'),
          icon: row.read<String>('icon'),
          color: row.read<int>('color'),
          total: row.read<int>('total'),
        ),
    ];
  }
}
