import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/budget/data/budgets_dao.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';

/// How many months back a leftover can come from.
const rolloverMonths = 12;

/// The monthly budget: reading it with what was spent, setting limits and
/// copying last month's. Months are calendar months, starting on the 1st.
class BudgetsRepository {
  BudgetsRepository(this._db);

  final AppDatabase _db;

  /// The budgets of [month] (any day in it). Emits again when a budget or an
  /// expense changes.
  Stream<MonthBudget> watchMonth(DateTime month) {
    final range = monthRange(month);
    return _db.budgetsDao
        .watchForMonthWithSpent(monthKey(month), range.start, range.end)
        .asyncMap(
          (rows) async =>
              _toMonthBudget(range.start, rows, await _carriedInto(month)),
        );
  }

  /// The overall budget of [month] with what was spent, or null when the month
  /// has none. A one-off read; see [watchMonth] for one that updates.
  Future<BudgetItem?> overallBudget(DateTime month) async {
    final range = monthRange(month);
    final rows = await _db.budgetsDao.getForMonthWithSpent(
      monthKey(month),
      range.start,
      range.end,
    );
    final carried = await _carriedInto(month);
    for (final row in rows) {
      if (row.categoryId == null) return _toBudgetItem(row, carried);
    }
    return null;
  }

  /// What each budget of [month] gets from the months before, by category id
  /// (null: the overall budget). Empty when carrying over is off.
  ///
  /// A month's leftover is its limit (with what it got itself) minus what was
  /// spent, when that is above zero: overspending does not take anything
  /// off the next month. A month without that budget breaks the chain. Only
  /// the last [rolloverMonths] months count.
  Future<Map<int?, int>> _carriedInto(DateTime month) async {
    final settings = await _db.settingsDao.getAll();
    if (settings[PreferenceKeys.budgetRollover] != 'true') return const {};

    var carried = <int?, int>{};
    for (var back = rolloverMonths; back >= 1; back--) {
      final earlier = addMonths(monthStart(month), -back);
      final range = monthRange(earlier);
      final rows = await _db.budgetsDao.getForMonthWithSpent(
        monthKey(earlier),
        range.start,
        range.end,
      );
      final next = <int?, int>{};
      for (final row in rows) {
        final left = row.amount + (carried[row.categoryId] ?? 0) - row.spent;
        if (left > 0) next[row.categoryId] = left;
      }
      carried = next;
    }
    return carried;
  }

  /// Sets the limit of [categoryId] in [month], or the overall limit when
  /// [categoryId] is null. Changes the limit if there already is one.
  Future<void> setBudget({
    required DateTime month,
    required int amount,
    int? categoryId,
  }) {
    return _db.transaction(() async {
      if (amount <= 0) {
        throw ValidationException(tr('The budget must be above zero.'));
      }
      final key = monthKey(month);
      final existing = await _db.budgetsDao.getByMonthAndCategory(
        key,
        categoryId,
      );
      if (existing != null) {
        await _db.budgetsDao.updateBudget(existing.copyWith(amount: amount));
        return;
      }
      if (categoryId != null) await _requireBudgetCategory(categoryId);
      await _db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: key,
          amount: amount,
          categoryId: Value(categoryId),
        ),
      );
    });
  }

  Future<void> removeBudget(int id) async {
    await _db.budgetsDao.deleteBudget(id);
  }

  /// Copies the budgets of the month before [month] into [month]. A budget
  /// that [month] already has is left as it is, and budgets of archived
  /// categories are not copied. Returns how many were copied.
  Future<int> copyFromPreviousMonth(DateTime month) {
    return _db.transaction(() async {
      final previous = addMonths(monthStart(month), -1);
      final source = await _db.budgetsDao.getForMonth(monthKey(previous));
      if (source.isEmpty) {
        throw ValidationException(
          tr('There is no budget in {month} to copy.', {
            'month': monthLabel(previous),
          }),
        );
      }

      final key = monthKey(month);
      final existing = {
        for (final row in await _db.budgetsDao.getForMonth(key)) row.categoryId,
      };
      var copied = 0;
      for (final row in source) {
        if (existing.contains(row.categoryId)) continue;
        if (row.categoryId != null) {
          final category = await _db.categoriesDao.getById(row.categoryId!);
          if (category == null || category.isArchived) continue;
        }
        await _db.budgetsDao.insertBudget(
          BudgetsCompanion.insert(
            month: key,
            amount: row.amount,
            categoryId: Value(row.categoryId),
          ),
        );
        copied++;
      }
      return copied;
    });
  }

  Future<void> _requireBudgetCategory(int categoryId) async {
    final category = await _db.categoriesDao.getById(categoryId);
    if (category == null) {
      throw ValidationException(tr('Category not found.'));
    }
    if (category.type != CategoryType.expense) {
      throw ValidationException(
        tr('Only an expense category can have a budget.'),
      );
    }
    if (category.isArchived) {
      throw ValidationException(
        tr('The category "{name}" is archived.', {'name': category.name}),
      );
    }
  }

  BudgetItem _toBudgetItem(BudgetWithSpent row, Map<int?, int> carried) {
    final carriedOver = carried[row.categoryId] ?? 0;
    return BudgetItem(
      id: row.id,
      categoryId: row.categoryId,
      categoryName: row.categoryName,
      categoryIcon: row.categoryIcon,
      categoryColor: row.categoryColor,
      limit: row.amount + carriedOver,
      carriedOver: carriedOver,
      spent: row.spent,
    );
  }

  MonthBudget _toMonthBudget(
    DateTime month,
    List<BudgetWithSpent> rows,
    Map<int?, int> carried,
  ) {
    BudgetItem toItem(BudgetWithSpent row) => _toBudgetItem(row, carried);

    BudgetItem? overall;
    final categories = <BudgetItem>[];
    for (final row in rows) {
      if (row.categoryId == null) {
        overall = toItem(row);
      } else {
        categories.add(toItem(row));
      }
    }
    return MonthBudget(
      month: month,
      overall: overall,
      categories: sortBudgetItems(categories),
    );
  }
}
