import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/budget/data/budgets_table.dart';

part 'budgets_dao.g.dart';

@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.attachedDatabase);

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
