import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// What a tidy-up of the categories did.
class TidyResult {
  const TidyResult({this.merged = 0, this.moved = 0, this.transactions = 0});

  /// Categories folded into the one they doubled.
  final int merged;

  /// Categories moved to where they belong (a person's pocket money).
  final int moved;

  /// Transactions that changed category by the merges.
  final int transactions;

  bool get isEmpty => merged == 0 && moved == 0;

  TidyResult operator +(TidyResult other) => TidyResult(
    merged: merged + other.merged,
    moved: moved + other.moved,
    transactions: transactions + other.transactions,
  );
}

String _norm(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Puts the categories in order without losing a single transaction:
///
/// 1. **Family by person**: the old *Family & gifts > Pocket money > Wife /
///    Husband / Children* become *Wife > Pocket money* and so on, inside a
///    group for each person. When the person already has a *Pocket money*
///    (the old *Children > Pocket money*), the two are merged.
/// 2. **Doubles**: two active categories of one type with the same name in the
///    same place are one category. The one with more transactions stays, the
///    other is folded into it (see [CategoriesRepository.mergeCategory]), and
///    what was inside it moves into the one that stays, where the same rule
///    then applies again.
///
/// Names that only look alike ("Bus & rickshaw" and "Bus") are not touched:
/// only the person knows what an old entry was. See
/// docs/specs/categories/tidy-up.md.
class CategoryTidy {
  CategoryTidy(this._db) : _repository = CategoriesRepository(_db);

  final AppDatabase _db;
  final CategoriesRepository _repository;

  /// The people of the house that get a group in *Family & gifts*.
  static const people = ['Wife', 'Husband', 'Children'];

  Future<TidyResult> run() async =>
      await familyByPerson() + await mergeDoubles();

  Future<List<Category>> _all() async => [
    for (final row in await _db.categoriesDao.getAll(includeArchived: true))
      row.toDomain(),
  ];

  Future<bool> _used(int id) async {
    for (final table in const [
      'transactions',
      'budgets',
      'recurring_rules',
      'challenges',
    ]) {
      final row = await _db
          .customSelect(
            'SELECT 1 FROM $table WHERE category_id = ? LIMIT 1',
            variables: [Variable.withInt(id)],
          )
          .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  /// The active category [name] inside [parentId] (a top-level one when null).
  Category? _child(List<Category> all, int? parentId, String name) {
    for (final category in all) {
      if (!category.isArchived &&
          category.type == CategoryType.expense &&
          category.parentId == parentId &&
          _norm(category.name) == _norm(name)) {
        return category;
      }
    }
    return null;
  }

  /// Step 1. Returns how many categories were moved or merged.
  Future<TidyResult> familyByPerson() async {
    var all = await _all();
    final family = _child(all, null, 'Family & gifts');
    final pocket = family == null
        ? null
        : _child(all, family.id, 'Pocket money');
    if (family == null || pocket == null) return const TidyResult();

    var moved = 0;
    var merged = 0;
    var transactions = 0;
    for (final person in people) {
      final old = _child(all, pocket.id, person);
      if (old == null) continue;
      try {
        final nodeId =
            _child(all, family.id, person)?.id ??
            await _repository.createCategory(
              name: person,
              type: CategoryType.expense,
              parentId: family.id,
              icon: switch (person) {
                'Wife' => 'spa',
                'Husband' => 'work',
                _ => 'child_care',
              },
              color: family.color,
            );
        all = await _all();
        final existing = _child(all, nodeId, 'Pocket money');
        if (existing == null) {
          await _db.customStatement(
            'UPDATE categories SET parent_id = ?, name = ?, icon = ? '
            'WHERE id = ?',
            [nodeId, 'Pocket money', 'wallet', old.id],
          );
          moved++;
        } else {
          final result = await _repository.mergeCategory(
            old.id,
            intoId: existing.id,
          );
          merged++;
          transactions += result.transactions;
        }
        all = await _all();
      } on ValidationException {
        // Something the person built in there: leave this one as it is.
      }
    }

    // The old group is empty now: put it away, but only when nothing is
    // attached to it.
    all = await _all();
    final stillHolds = all.any((c) => !c.isArchived && c.parentId == pocket.id);
    if (!stillHolds && !await _used(pocket.id)) {
      await _db.categoriesDao.setArchived(pocket.id, archived: true);
    }
    return TidyResult(merged: merged, moved: moved, transactions: transactions);
  }

  /// Step 2. Folds every double into the one that stays; repeats while a fold
  /// made a new double (two doubled groups hold the same child).
  Future<TidyResult> mergeDoubles() async {
    var total = const TidyResult();
    for (var pass = 0; pass < 8; pass++) {
      final all = await _all();
      final groups = <String, List<Category>>{};
      for (final category in all) {
        if (category.isArchived) continue;
        groups
            .putIfAbsent(
              '${category.type.name}|${category.parentId}|${_norm(category.name)}',
              () => [],
            )
            .add(category);
      }
      var changed = false;
      for (final group in groups.values) {
        if (group.length < 2) continue;
        final uses = <int, int>{};
        for (final category in group) {
          final row = await _db
              .customSelect(
                'SELECT COUNT(*) AS n FROM transactions WHERE category_id = ?',
                variables: [Variable.withInt(category.id)],
              )
              .getSingle();
          uses[category.id] = row.read<int>('n');
        }
        group.sort((a, b) {
          final byUse = uses[b.id]!.compareTo(uses[a.id]!);
          return byUse != 0 ? byUse : a.id.compareTo(b.id);
        });
        final keep = group.first;
        for (final double in group.skip(1)) {
          try {
            await _db.customStatement(
              'UPDATE categories SET parent_id = ? '
              'WHERE parent_id = ? AND is_archived = 0',
              [keep.id, double.id],
            );
            final result = await _repository.mergeCategory(
              double.id,
              intoId: keep.id,
            );
            total += TidyResult(merged: 1, transactions: result.transactions);
            changed = true;
          } on ValidationException {
            // Not possible here: leave this double for the person.
          }
        }
      }
      if (!changed) break;
    }
    return total;
  }
}
