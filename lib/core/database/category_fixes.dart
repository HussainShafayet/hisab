import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/data/legacy_defaults.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// Version 18: the default "Kids pocket money" sat straight inside
/// "Family & gifts", next to "Children" instead of inside it. Moves it into
/// "Children" and calls it "Pocket money", like the new defaults. Only touches
/// the default layout: if the person moved or renamed either category, or
/// "Children" already has a "Pocket money", it is left as it is (apart from
/// the move, which keeps its name then). Transactions keep their category id,
/// so nothing else changes.
Future<void> moveKidsPocketMoney(DatabaseConnectionUser db) async {
  final found = await db
      .customSelect(
        'SELECT k.id AS kid, c.id AS children FROM categories f '
        'JOIN categories k ON k.parent_id = f.id '
        "AND k.name = 'Kids pocket money' "
        "JOIN categories c ON c.parent_id = f.id AND c.name = 'Children' "
        "WHERE f.parent_id IS NULL AND f.name = 'Family & gifts' "
        "AND f.type = 'expense' LIMIT 1",
      )
      .getSingleOrNull();
  if (found == null) return;
  final kid = found.read<int>('kid');
  final children = found.read<int>('children');
  final taken = await db
      .customSelect(
        'SELECT 1 FROM categories WHERE parent_id = ? '
        "AND lower(name) = 'pocket money' LIMIT 1",
        variables: [Variable.withInt(children)],
      )
      .getSingleOrNull();
  await db.customStatement(
    'UPDATE categories SET parent_id = ?, name = ? WHERE id = ?',
    [children, taken == null ? 'Pocket money' : 'Kids pocket money', kid],
  );
}

/// Version 19: the default categories were split ("Bus & rickshaw" became Bus
/// and Rickshaw) and made to hold each thing in one place only. An install
/// that has the old defaults:
///
/// 1. retires the old default categories that are no longer defaults: one is
///    archived only when nothing uses it (no transaction, budget, repeating
///    entry or challenge) and nothing active sits inside it, so no history
///    moves or disappears and what the person made is never touched;
/// 2. adds the new defaults it does not have yet.
///
/// A category the person renamed is not recognised, so it is left alone. An
/// install without the default food groups (a custom or empty one) is not
/// touched at all.
Future<void> refreshDefaultCategories(AppDatabase db) async {
  final rows = await db.categoriesDao.getAll(includeArchived: true);
  final domain = [for (final row in rows) row.toDomain()];
  final byId = {for (final c in domain) c.id: c};
  final byKey = <(CategoryType, String), Category>{};
  for (final c in domain) {
    byKey.putIfAbsent((c.type, pathKey(pathOf(c, byId))), () => c);
  }
  // Not an install that was made with the defaults.
  if (byKey[(CategoryType.expense, pathKey(['Food', 'Kacha bazar']))] == null) {
    return;
  }

  final archived = <int>{
    for (final c in domain)
      if (c.isArchived) c.id,
  };
  bool hasActiveChild(int id) =>
      domain.any((c) => c.parentId == id && !archived.contains(c.id));

  Future<bool> used(int id) async {
    for (final table in const [
      'transactions',
      'budgets',
      'recurring_rules',
      'challenges',
    ]) {
      final row = await db
          .customSelect(
            'SELECT 1 FROM $table WHERE category_id = ? LIMIT 1',
            variables: [Variable.withInt(id)],
          )
          .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  Future<void> retire(
    CategoryType type,
    Iterable<String> oldPaths,
    List<DefaultCategory> current,
  ) async {
    final stillDefault = {
      for (final e in flattenDefaults(current)) pathKey(e.path),
    };
    final retired = [
      for (final path in oldPaths)
        if (!stillDefault.contains(pathKey(path.split(' > '))))
          path.split(' > '),
    ]..sort((a, b) => b.length.compareTo(a.length));
    for (final names in retired) {
      final category = byKey[(type, pathKey(names))];
      if (category == null || archived.contains(category.id)) continue;
      if (hasActiveChild(category.id) || await used(category.id)) continue;
      await db.categoriesDao.setArchived(category.id, archived: true);
      archived.add(category.id);
    }
  }

  await retire(CategoryType.expense, [
    ...legacyExpensePaths,
    ...legacyOlderExpensePaths,
  ], defaultExpenseCategories);
  await retire(CategoryType.income, legacyIncomePaths, defaultIncomeCategories);
  await CategoriesRepository(db).addMissingDefaults();
}
