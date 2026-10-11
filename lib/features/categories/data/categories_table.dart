import 'package:drift/drift.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// Rows are never deleted, only archived (see [isArchived]), so old
/// transactions always keep a valid category.
@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get type => textEnum<CategoryType>()();

  /// Null for a top-level category, otherwise the id of its parent.
  IntColumn get parentId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Key of a Material icon, e.g. `restaurant`. Resolved to an `IconData` by
  /// the UI, so the database never depends on Flutter.
  TextColumn get icon => text().withDefault(const Constant('category'))();

  /// ARGB value, e.g. `0xFF4CAF50`.
  IntColumn get color => integer().withDefault(const Constant(0xFF9E9E9E))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
