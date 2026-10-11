import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// Everything the UI needs to know about categories. Validates input, turns
/// database rows into domain models and enforces the category rules:
/// one level of sub-categories, a sub-category has its parent's type, names
/// are unique among siblings, and nothing is ever deleted, only archived.
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
  /// [parentId] and the same [type] as that parent.
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
      _validateParent(
        all,
        parentId: parentId,
        type: current.type,
        categoryId: id,
      );
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

  /// Hides the category and its sub-categories from lists. Transactions that
  /// use them are untouched.
  Future<void> archiveCategory(int id) => _setArchived(id, archived: true);

  /// Brings the category and its sub-categories back. A sub-category cannot
  /// be restored while its parent is archived.
  Future<void> restoreCategory(int id) => _setArchived(id, archived: false);

  Future<void> _setArchived(int id, {required bool archived}) {
    return _db.transaction(() async {
      final all = await _db.categoriesDao.getAll(includeArchived: true);
      final target = _requireRow(all, id);

      if (!archived && target.parentId != null) {
        final parent = all.firstWhere((c) => c.id == target.parentId);
        if (parent.isArchived) {
          throw ValidationException(
            'Restore "${parent.name}" first, it is this sub-category\'s parent.',
          );
        }
      }

      await _db.categoriesDao.setArchived(id, archived: archived);
      for (final child in all.where((c) => c.parentId == id)) {
        await _db.categoriesDao.setArchived(child.id, archived: archived);
      }
    });
  }

  CategoryRow _requireRow(List<CategoryRow> all, int id) {
    for (final row in all) {
      if (row.id == id) return row;
    }
    throw const ValidationException('Category not found.');
  }

  String _validatedName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) throw const ValidationException('Name is required.');
    if (name.length > maxNameLength) {
      throw const ValidationException(
        'Name must be $maxNameLength characters or fewer.',
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
    if (parentId == null) return;
    if (parentId == categoryId) {
      throw const ValidationException('A category cannot be its own parent.');
    }
    final parent = _requireRow(all, parentId);
    if (parent.parentId != null) {
      throw const ValidationException(
        'Sub-categories can only go one level deep.',
      );
    }
    if (parent.type != type) {
      throw const ValidationException(
        'A sub-category must have the same type as its parent.',
      );
    }
    if (parent.isArchived) {
      throw const ValidationException('The parent category is archived.');
    }
    if (categoryId != null && all.any((c) => c.parentId == categoryId)) {
      throw const ValidationException(
        'A category that has sub-categories cannot become a sub-category.',
      );
    }
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
              ? 'An archived category named "${other.name}" exists here. '
                    'Restore it instead.'
              : 'A category named "${other.name}" already exists here.',
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
