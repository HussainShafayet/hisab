import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// What a merge of two categories moved.
class MergeResult {
  const MergeResult({
    required this.transactions,
    required this.budgets,
    required this.rules,
    required this.challenges,
  });

  final int transactions;
  final int budgets;
  final int rules;
  final int challenges;
}

/// Everything the UI needs to know about categories. Validates input, turns
/// database rows into domain models and enforces the category rules:
/// categories can sit inside categories up to [maxCategoryDepth] levels, a
/// sub-category has its parent's type, names are unique among siblings, and
/// nothing is ever deleted, only archived.
class CategoriesRepository {
  CategoriesRepository(this._db);

  final AppDatabase _db;

  static const maxNameLength = 60;

  /// Income and expense categories together, parents and sub-categories mixed.
  /// Use `buildCategoryTree` to group them.
  Stream<List<Category>> watchCategories({bool includeArchived = false}) {
    return _db.categoriesDao
        .watchAll(includeArchived: includeArchived)
        .map((rows) => rows.map((row) => row.toDomain()).toList());
  }

  /// A one-off read of the categories, for when a stream is not needed.
  Future<List<Category>> getCategories({bool includeArchived = false}) async {
    final rows = await _db.categoriesDao.getAll(
      includeArchived: includeArchived,
    );
    return [for (final row in rows) row.toDomain()];
  }

  Future<Category?> getCategory(int id) async {
    final row = await _db.categoriesDao.getById(id);
    return row?.toDomain();
  }

  /// Returns the new category's id. A sub-category passes its parent's
  /// [parentId] (which can itself be a sub-category) and the same [type] as
  /// that parent.
  Future<int> createCategory({
    required String name,
    required CategoryType type,
    int? parentId,
    required String icon,
    required int color,
  }) {
    return _db.transaction(() async {
      final all = await _db.categoriesDao.getAll(includeArchived: true);
      final cleanName = _validatedName(name);
      _validateParent(all, parentId: parentId, type: type);
      _ensureNameFree(all, cleanName, type: type, parentId: parentId);
      return _db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(
          name: cleanName,
          type: type,
          parentId: Value(parentId),
          icon: Value(icon),
          color: Value(color),
          sortOrder: Value(_nextSortOrder(all, type: type, parentId: parentId)),
        ),
      );
    });
  }

  /// Adds the default categories this install is missing (the Bangladesh
  /// daily-life ones) and returns how many were added. Nothing that exists is
  /// changed or brought back.
  Future<int> addMissingDefaults() {
    return _db.transaction(() async {
      final rows = await _db.categoriesDao.getAll(includeArchived: true);
      final domain = [for (final row in rows) row.toDomain()];
      final byId = {for (final c in domain) c.id: c};
      final planned = missingDefaults(domain);
      // Ids by type and path of names, the new ones added as they are made.
      final ids = <(CategoryType, String), int>{};
      for (final category in domain) {
        ids.putIfAbsent((
          category.type,
          pathKey(pathOf(category, byId)),
        ), () => category.id);
      }
      final nextOrder = <(CategoryType, int?), int>{};

      for (final item in planned) {
        final parentId = item.parentPath.isEmpty
            ? null
            : ids[(item.type, pathKey(item.parentPath))];
        final slot = (item.type, parentId);
        final order =
            nextOrder[slot] ??
            _nextSortOrder(rows, type: item.type, parentId: parentId);
        nextOrder[slot] = order + 1;
        final id = await _db.categoriesDao.insertCategory(
          CategoriesCompanion.insert(
            name: item.name,
            type: item.type,
            parentId: Value(parentId),
            icon: Value(item.icon),
            color: Value(item.color),
            sortOrder: Value(order),
          ),
        );
        ids[(item.type, pathKey([...item.parentPath, item.name]))] = id;
      }
      return planned.length;
    });
  }

  /// The type of a category never changes, because old transactions depend
  /// on it. Pass a different [parentId] to move it, or null to make it
  /// top-level.
  Future<void> updateCategory(
    int id, {
    required String name,
    required int? parentId,
    required String icon,
    required int color,
  }) {
    return _db.transaction(() async {
      final all = await _db.categoriesDao.getAll(includeArchived: true);
      final current = _requireRow(all, id);
      final cleanName = _validatedName(name);
      // An unchanged parent is not checked again: a category can be renamed
      // while its parent is archived.
      if (parentId != current.parentId) {
        _validateParent(
          all,
          parentId: parentId,
          type: current.type,
          categoryId: id,
        );
      }
      _ensureNameFree(
        all,
        cleanName,
        type: current.type,
        parentId: parentId,
        excludeId: id,
      );
      final moved = parentId != current.parentId;
      await _db.categoriesDao.updateCategory(
        current.copyWith(
          name: cleanName,
          parentId: Value(parentId),
          icon: icon,
          color: color,
          sortOrder: moved
              ? _nextSortOrder(all, type: current.type, parentId: parentId)
              : current.sortOrder,
        ),
      );
    });
  }

  /// Hides the category and everything inside it from lists. Transactions
  /// that use them are untouched.
  Future<void> archiveCategory(int id) => _setArchived(id, archived: true);

  /// Brings the category and everything inside it back. A sub-category
  /// cannot be restored while its parent is archived.
  Future<void> restoreCategory(int id) => _setArchived(id, archived: false);

  Future<void> _setArchived(int id, {required bool archived}) {
    return _db.transaction(() async {
      final all = await _db.categoriesDao.getAll(includeArchived: true);
      final target = _requireRow(all, id);

      if (!archived && target.parentId != null) {
        final parent = all.firstWhere((c) => c.id == target.parentId);
        if (parent.isArchived) {
          throw ValidationException(
            tr('Restore "{name}" first, it is this sub-category\'s parent.', {
              'name': parent.name,
            }),
          );
        }
      }

      final everyone = categoryAndDescendantIds(
        id,
        all.map((row) => row.toDomain()),
      );
      for (final affected in everyone) {
        await _db.categoriesDao.setArchived(affected, archived: archived);
      }
    });
  }

  /// Folds category [fromId] into [intoId]: its transactions, its budgets
  /// (added to the budget of the other for the same month), its repeating
  /// entries and its challenges all go to [intoId], and [fromId] is archived.
  /// Both must be of one type, [intoId] must not be archived, and [fromId]
  /// must have no sub-categories in use. All or nothing.
  Future<MergeResult> mergeCategory(int fromId, {required int intoId}) {
    return _db.transaction(() async {
      if (fromId == intoId) {
        throw ValidationException(tr('Choose another category to merge into.'));
      }
      final all = await _db.categoriesDao.getAll(includeArchived: true);
      final from = _requireRow(all, fromId);
      final into = _requireRow(all, intoId);
      if (from.type != into.type) {
        throw ValidationException(
          tr('A category can only be merged into one of the same type.'),
        );
      }
      if (into.isArchived) {
        throw ValidationException(
          tr('The category "{name}" is archived.', {'name': into.name}),
        );
      }
      if (all.any((c) => c.parentId == fromId && !c.isArchived)) {
        throw ValidationException(
          tr('"{name}" has sub-categories. Move or merge them first.', {
            'name': from.name,
          }),
        );
      }

      Future<int> move(String table, TableInfo<Table, dynamic> affected) {
        return _db.customUpdate(
          'UPDATE $table SET category_id = ? WHERE category_id = ?',
          variables: [Variable.withInt(intoId), Variable.withInt(fromId)],
          updates: {affected},
        );
      }

      final transactions = await move('transactions', _db.transactions);
      final rules = await move('recurring_rules', _db.recurringRules);
      final challenges = await move('challenges', _db.challenges);

      // One budget per month and category: when both have one, they add up.
      final budgetRows = await (_db.select(
        _db.budgets,
      )..where((b) => b.categoryId.equals(fromId))).get();
      for (final budget in budgetRows) {
        final same =
            await (_db.select(_db.budgets)..where(
                  (b) =>
                      b.categoryId.equals(intoId) &
                      b.month.equals(budget.month),
                ))
                .getSingleOrNull();
        if (same == null) {
          await (_db.update(_db.budgets)..where((b) => b.id.equals(budget.id)))
              .write(BudgetsCompanion(categoryId: Value(intoId)));
        } else {
          await (_db.update(
            _db.budgets,
          )..where((b) => b.id.equals(same.id))).write(
            BudgetsCompanion(amount: Value(same.amount + budget.amount)),
          );
          await (_db.delete(
            _db.budgets,
          )..where((b) => b.id.equals(budget.id))).go();
        }
      }

      await _db.categoriesDao.setArchived(fromId, archived: true);
      return MergeResult(
        transactions: transactions,
        budgets: budgetRows.length,
        rules: rules,
        challenges: challenges,
      );
    });
  }

  CategoryRow _requireRow(List<CategoryRow> all, int id) {
    for (final row in all) {
      if (row.id == id) return row;
    }
    throw ValidationException(tr('Category not found.'));
  }

  String _validatedName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) throw ValidationException(tr('Name is required.'));
    if (name.length > maxNameLength) {
      throw ValidationException(
        tr('Name must be {max} characters or fewer.', {'max': maxNameLength}),
      );
    }
    return name;
  }

  void _validateParent(
    List<CategoryRow> all, {
    required int? parentId,
    required CategoryType type,
    int? categoryId,
  }) {
    final problem = categoryParentProblem(
      all: all.map((row) => row.toDomain()),
      type: type,
      parentId: parentId,
      categoryId: categoryId,
    );
    if (problem != null) throw ValidationException(problem);
  }

  void _ensureNameFree(
    List<CategoryRow> all,
    String name, {
    required CategoryType type,
    required int? parentId,
    int? excludeId,
  }) {
    for (final other in all) {
      if (other.id != excludeId &&
          other.type == type &&
          other.parentId == parentId &&
          other.name.toLowerCase() == name.toLowerCase()) {
        throw ValidationException(
          other.isArchived
              ? tr(
                  'An archived category named "{name}" exists here. '
                  'Restore it instead.',
                  {'name': other.name},
                )
              : tr('A category named "{name}" already exists here.', {
                  'name': other.name,
                }),
        );
      }
    }
  }

  int _nextSortOrder(
    List<CategoryRow> all, {
    required CategoryType type,
    required int? parentId,
  }) {
    var highest = -1;
    for (final other in all) {
      if (other.type == type &&
          other.parentId == parentId &&
          other.sortOrder > highest) {
        highest = other.sortOrder;
      }
    }
    return highest + 1;
  }
}
