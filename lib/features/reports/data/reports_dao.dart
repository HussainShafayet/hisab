import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/database/category_tree_sql.dart';
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

  /// Expenses grouped by top-level category, biggest first. The spending of
  /// a sub-category, at any depth, counts for the top-level category it is in.
  Future<List<CategoryTotalRow>> expenseByCategory(
    DateTime start,
    DateTime end,
  ) => _byCategory(TransactionType.expense, start, end);

  /// Income grouped by top-level category, biggest first.
  Future<List<CategoryTotalRow>> incomeByCategory(
    DateTime start,
    DateTime end,
  ) => _byCategory(TransactionType.income, start, end);

  Future<List<CategoryTotalRow>> _byCategory(
    TransactionType type,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await customSelect(
      '${categoryTreeCte}SELECT p.id AS category_id, p.name AS name, '
      'p.icon AS icon, p.color AS color, SUM(t.amount) AS total '
      'FROM transactions t '
      'JOIN category_tree ct ON ct.id = t.category_id '
      'JOIN categories p ON p.id = ct.root_id AND p.parent_id IS NULL '
      "WHERE t.type = '${type.name}' "
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

  /// What was put directly on each category in the range, by category id:
  /// the category's own money, without what is in the categories inside it.
  Future<Map<int, int>> ownTotalsByCategory(
    TransactionType type,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await customSelect(
      'SELECT category_id, SUM(amount) AS total FROM transactions '
      "WHERE type = '${type.name}' AND is_adjustment = 0 "
      'AND category_id IS NOT NULL AND date >= ? AND date < ? '
      'GROUP BY category_id',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactions},
    ).get();
    return {
      for (final row in rows)
        row.read<int>('category_id'): row.read<int>('total'),
    };
  }

  /// Income and expense of each account in the range, the busiest first.
  Future<List<({int accountId, String name, int income, int expense})>>
  incomeExpenseByAccount(DateTime start, DateTime end) async {
    final income = TransactionType.income.name;
    final expense = TransactionType.expense.name;
    final rows = await customSelect(
      'SELECT a.id AS account_id, a.name AS name, '
      "COALESCE(SUM(CASE WHEN t.type = '$income' THEN t.amount END), 0) AS income, "
      "COALESCE(SUM(CASE WHEN t.type = '$expense' THEN t.amount END), 0) AS expense "
      'FROM transactions t JOIN accounts a ON a.id = t.account_id '
      'WHERE t.date >= ? AND t.date < ? AND t.is_adjustment = 0 '
      "AND t.type IN ('$income', '$expense') "
      'GROUP BY a.id ORDER BY (income + expense) DESC, a.id',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactions, attachedDatabase.accounts},
    ).get();
    return [
      for (final row in rows)
        (
          accountId: row.read<int>('account_id'),
          name: row.read<String>('name'),
          income: row.read<int>('income'),
          expense: row.read<int>('expense'),
        ),
    ];
  }
}
