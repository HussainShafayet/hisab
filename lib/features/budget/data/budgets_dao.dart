import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/budget/data/budgets_table.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

part 'budgets_dao.g.dart';

/// A budget with its category (when it has one) and what has been spent.
typedef BudgetWithSpent = ({
  int id,
  int amount,
  int spent,
  int? categoryId,
  String? categoryName,
  String? categoryIcon,
  int? categoryColor,
});

@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.attachedDatabase);

  /// Every budget of every month.
  Future<List<BudgetRow>> getAll() =>
      (select(budgets)..orderBy([(b) => OrderingTerm.asc(b.id)])).get();

  /// All budgets of a month (`YYYY-MM`): the overall one (null category) and
  /// the per-category ones.
  Stream<List<BudgetRow>> watchForMonth(String month) =>
      (select(budgets)
            ..where((b) => b.month.equals(month))
            ..orderBy([(b) => OrderingTerm.asc(b.id)]))
          .watch();

  Future<List<BudgetRow>> getForMonth(String month) =>
      (select(budgets)
            ..where((b) => b.month.equals(month))
            ..orderBy([(b) => OrderingTerm.asc(b.id)]))
          .get();

  /// The budget of [categoryId] (null for the overall one) in [month].
  Future<BudgetRow?> getByMonthAndCategory(String month, int? categoryId) {
    final query = select(budgets)
      ..where(
        (b) =>
            b.month.equals(month) &
            (categoryId == null
                ? b.categoryId.isNull()
                : b.categoryId.equals(categoryId)),
      );
    return query.getSingleOrNull();
  }

  /// The budgets of [month] with what was spent against each, calculated by
  /// SQLite. [start] and [end] are the local start of the month and of the
  /// next one. Emits again when a budget, a category or a transaction changes.
  ///
  /// What counts as spent: expenses only. Transfers are movements between
  /// accounts and balance adjustments are corrections, so both are left out.
  /// A category budget also counts its sub-categories.
  Stream<List<BudgetWithSpent>> watchForMonthWithSpent(
    String month,
    DateTime start,
    DateTime end,
  ) => _selectWithSpent(month, start, end).watch();

  Future<List<BudgetWithSpent>> getForMonthWithSpent(
    String month,
    DateTime start,
    DateTime end,
  ) => _selectWithSpent(month, start, end).get();

  Selectable<BudgetWithSpent> _selectWithSpent(
    String month,
    DateTime start,
    DateTime end,
  ) {
    // The type name comes from our own enum, never from user input.
    final expense = TransactionType.expense.name;
    String spent(String extraCondition) =>
        '(SELECT COALESCE(SUM(t.amount), 0) FROM transactions t '
        "WHERE t.type = '$expense' AND t.is_adjustment = 0 "
        'AND t.date >= ? AND t.date < ? $extraCondition)';

    return customSelect(
      'SELECT b.id, b.amount, b.category_id, '
      'c.name AS category_name, c.icon AS category_icon, '
      'c.color AS category_color, '
      'CASE WHEN b.category_id IS NULL THEN ${spent('')} '
      'ELSE ${spent('AND (t.category_id = b.category_id OR t.category_id IN '
      '(SELECT id FROM categories WHERE parent_id = b.category_id))')} '
      'END AS spent '
      'FROM budgets b LEFT JOIN categories c ON c.id = b.category_id '
      'WHERE b.month = ? ORDER BY b.id',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withString(month),
      ],
      readsFrom: {
        budgets,
        attachedDatabase.transactions,
        attachedDatabase.categories,
      },
    ).map(
      (row) => (
        id: row.read<int>('id'),
        amount: row.read<int>('amount'),
        spent: row.read<int>('spent'),
        categoryId: row.readNullable<int>('category_id'),
        categoryName: row.readNullable<String>('category_name'),
        categoryIcon: row.readNullable<String>('category_icon'),
        categoryColor: row.readNullable<int>('category_color'),
      ),
    );
  }

  /// Returns the new id. Fails if that month and category already have a
  /// budget.
  Future<int> insertBudget(BudgetsCompanion budget) =>
      into(budgets).insert(budget);

  /// Replaces the whole row. Returns false if the id does not exist.
  Future<bool> updateBudget(BudgetRow budget) =>
      update(budgets).replace(budget);

  Future<int> deleteBudget(int id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();
}
