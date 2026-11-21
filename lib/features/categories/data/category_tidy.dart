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
/// 3. **One place for each thing**: what every person has (Clothes, Medicine,
///    Doctor, Gifts, Outings, Jewellery, Cosmetics, Parlour) inside Wife /
///    Husband / Children is folded into the one place it belongs (Shopping,
///    Health, Gifts, Entertainment, Personal care), see [personRepeats].
/// 4. **Look-alikes in other layers**: two active categories of one type whose
///    names are the same words ("Gifts" and "Gift", "Medicine & doctor" and
///    "Doctor & medicine") are one, wherever they sit, see [mergeLookalikes].
///    Names inside a person's group, and generic names like "Other", are left.
///
/// Names that only share some words ("Bus & rickshaw" and "Bus") are not
/// touched: only the person knows what an old entry was. See
/// docs/specs/categories/tidy-up.md.
class CategoryTidy {
  CategoryTidy(this._db) : _repository = CategoriesRepository(_db);

  final AppDatabase _db;
  final CategoriesRepository _repository;

  /// The people of the house that get a group in *Family & gifts*.
  static const people = ['Wife', 'Husband', 'Children'];

  Future<TidyResult> run() async =>
      await familyByPerson() +
      await mergeDoubles() +
      await personRepeats() +
      await mergeLookalikes();

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

  /// What every person has, by its name inside a person's group, and where it
  /// lives once (a path of names from the top).
  static const _personRepeats = <String, List<String>>{
    'clothes': ['Shopping', 'Clothing'],
    'jewellery': ['Shopping', 'Clothing', 'Jewellery'],
    'cosmetics': ['Personal care', 'Cosmetics'],
    'parlour': ['Personal care', 'Parlour'],
    'medicine': ['Health', 'Medicine'],
    'doctor': ['Health', 'Doctor & tests', 'Doctor visit'],
    'gifts': ['Family & gifts', 'Gifts'],
    'outings': ['Entertainment', 'Outings'],
  };

  /// Names that mean something different in each place they are used.
  static const _generic = {
    'other',
    'others',
    'misc',
    'miscellaneous',
    'general',
    'extra',
    'various',
  };

  /// The active expense category at the end of [path] (names from the top).
  Category? _atPath(List<Category> all, List<String> path) {
    Category? found;
    for (final name in path) {
      found = _child(all, found?.id, name);
      if (found == null) return null;
    }
    return found;
  }

  /// Folds [from] into [into]: what is inside [from] moves into [into] first
  /// (a category with sub-categories cannot be merged), then the merge moves
  /// the transactions. Nothing changes when it cannot be done.
  Future<TidyResult> _fold(Category from, {required Category into}) async {
    try {
      await _db.customStatement(
        'UPDATE categories SET parent_id = ? '
        'WHERE parent_id = ? AND is_archived = 0',
        [into.id, from.id],
      );
      final result = await _repository.mergeCategory(from.id, intoId: into.id);
      return TidyResult(merged: 1, transactions: result.transactions);
    } on ValidationException {
      return const TidyResult();
    }
  }

  /// Step 3. Clothes, Medicine, Doctor, Gifts, Outings, Jewellery, Cosmetics
  /// and Parlour inside Wife, Husband and Children are folded into the one
  /// place each belongs. A repeat whose place is gone (the person deleted or
  /// renamed it) stays where it is.
  Future<TidyResult> personRepeats() async {
    var all = await _all();
    final family = _child(all, null, 'Family & gifts');
    if (family == null) return const TidyResult();
    var total = const TidyResult();
    for (final person in people) {
      for (final entry in _personRepeats.entries) {
        all = await _all();
        final group = _child(all, family.id, person);
        final repeat = group == null ? null : _child(all, group.id, entry.key);
        final target = _atPath(all, entry.value);
        if (repeat == null || target == null || repeat.id == target.id) {
          continue;
        }
        total += await _fold(repeat, into: target);
      }
    }
    return total;
  }

  /// The words of a name, without case, "&" or "and", punctuation, order or a
  /// plural s: "Medicine & doctor" and "Doctor and medicines" give one key.
  static String _lookalikeKey(String name) {
    final words =
        name
            .toLowerCase()
            .replaceAll('&', ' ')
            .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty && w != 'and')
            .map(
              (w) => w.length > 3 && w.endsWith('s') && !w.endsWith('ss')
                  ? w.substring(0, w.length - 1)
                  : w,
            )
            .toList()
          ..sort();
    return words.join(' ');
  }

  /// Step 4. Folds categories of one type with the same words in their name,
  /// wherever they sit, into the one closest to the top (the one with more
  /// transactions when they are as high). Repeats while a fold made another.
  Future<TidyResult> mergeLookalikes() async {
    var total = const TidyResult();
    for (var pass = 0; pass < 8; pass++) {
      final all = await _all();
      final byId = {for (final c in all) c.id: c};

      int depth(Category c) {
        var d = 0;
        for (var p = c.parentId; p != null; p = byId[p]?.parentId) {
          d++;
          if (d > 20) break;
        }
        return d;
      }

      bool isAbove(Category a, Category b) {
        for (var p = b.parentId; p != null; p = byId[p]?.parentId) {
          if (p == a.id) return true;
        }
        return false;
      }

      // A person's own group is on purpose: its names repeat in each group.
      bool inPersonGroup(Category c) {
        final parent = byId[c.parentId];
        final grand = byId[parent?.parentId];
        return parent != null &&
            grand != null &&
            people.map(_norm).contains(_norm(parent.name)) &&
            _norm(grand.name) == _norm('Family & gifts');
      }

      final groups = <String, List<Category>>{};
      for (final category in all) {
        if (category.isArchived ||
            _generic.contains(_norm(category.name)) ||
            inPersonGroup(category)) {
          continue;
        }
        final key = _lookalikeKey(category.name);
        if (key.isEmpty) continue;
        groups
            .putIfAbsent('${category.type.name}|$key', () => [])
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
          final byDepth = depth(a).compareTo(depth(b));
          if (byDepth != 0) return byDepth;
          final byUse = uses[b.id]!.compareTo(uses[a.id]!);
          return byUse != 0 ? byUse : a.id.compareTo(b.id);
        });
        final keep = group.first;
        for (final other in group.skip(1)) {
          // One inside the other is a group and its part, not a repeat.
          if (isAbove(keep, other) || isAbove(other, keep)) continue;
          final result = await _fold(other, into: keep);
          if (!result.isEmpty) {
            total += result;
            changed = true;
          }
        }
      }
      if (!changed) break;
    }
    return total;
  }
}
