import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/data/categories_table.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

part 'categories_dao.g.dart';

/// Categories are never deleted, only archived, so there is deliberately no
/// delete method here.
@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.attachedDatabase);

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _selectAll({
    required CategoryType? type,
    required bool includeArchived,
  }) {
    final query = select(categories);
    if (type != null) {
      query.where((c) => c.type.equalsValue(type));
    }
    if (!includeArchived) {
      query.where((c) => c.isArchived.equals(false));
    }
    return query..orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.id),
    ]);
  }

  /// Ordered by `sort_order`, then id. Pass [type] to get only income or only
  /// expense categories. Parents and sub-categories are returned together;
  /// group them with `parentId`.
  Stream<List<CategoryRow>> watchAll({
    CategoryType? type,
    bool includeArchived = false,
  }) => _selectAll(type: type, includeArchived: includeArchived).watch();

  Future<List<CategoryRow>> getAll({
    CategoryType? type,
    bool includeArchived = false,
  }) => _selectAll(type: type, includeArchived: includeArchived).get();

  Future<CategoryRow?> getById(int id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Returns the new id.
  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  /// Replaces the whole row. Returns false if the id does not exist.
  Future<bool> updateCategory(CategoryRow category) =>
      update(categories).replace(category);

  Future<void> setArchived(int id, {required bool archived}) =>
      (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(isArchived: Value(archived)),
      );

  /// The id of the top-level category called [name] of [type], archived or
  /// not. Creates it when it does not exist yet. The match is on the exact
  /// name, so a category the user renamed is simply not found.
  Future<int> findOrCreateTopLevel(
    String name,
    CategoryType type, {
    required String icon,
    int? color,
  }) async {
    final existing = await getAll(type: type, includeArchived: true);
    for (final category in existing) {
      if (category.parentId == null && category.name == name) {
        return category.id;
      }
    }
    return insertCategory(
      CategoriesCompanion.insert(
        name: name,
        type: type,
        icon: Value(icon),
        color: color == null ? const Value.absent() : Value(color),
        sortOrder: Value(existing.length),
      ),
    );
  }

  Future<void> insertDefaults() async {
    await _insertDefaultsOfType(CategoryType.expense, defaultExpenseCategories);
    await _insertDefaultsOfType(CategoryType.income, defaultIncomeCategories);
  }

  Future<void> _insertDefaultsOfType(
    CategoryType type,
    List<DefaultCategory> defaults,
  ) async {
    for (final (index, category) in defaults.indexed) {
      final parentId = await into(categories).insert(
        CategoriesCompanion.insert(
          name: category.name,
          type: type,
          icon: Value(category.icon),
          color: Value(category.color),
          sortOrder: Value(index),
        ),
      );
      for (final (childIndex, childName) in category.children.indexed) {
        await into(categories).insert(
          CategoriesCompanion.insert(
            name: childName,
            type: type,
            parentId: Value(parentId),
            icon: Value(category.icon),
            color: Value(category.color),
            sortOrder: Value(childIndex),
          ),
        );
      }
    }
  }
}
