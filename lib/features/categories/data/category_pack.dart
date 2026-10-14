import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// One category the defaults have and an install does not.
class PlannedCategory {
  const PlannedCategory({
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
    this.parentPath = const [],
  });

  final CategoryType type;
  final String name;
  final String icon;
  final int color;

  /// The names from the top level down to the category it goes inside, empty
  /// for a top-level one. A parent that is missing too is planned before the
  /// categories inside it.
  final List<String> parentPath;
}

String _name(String name) => name.trim().toLowerCase();

/// The key of a path of names, without case or spaces around the names.
String pathKey(Iterable<String> names) => names.map(_name).join('\u0000');

/// The names from the top level down to [category], by walking up its parents.
List<String> pathOf(Category category, Map<int, Category> byId) {
  final names = <String>[];
  Category? current = category;
  // A cycle cannot happen, but the walk stops after the deepest tree anyway.
  for (var step = 0; current != null && step < 20; step++) {
    names.add(current.name);
    current = byId[current.parentId];
  }
  return names.reversed.toList();
}

/// What the defaults have that [existing] does not, parents first. Names are
/// compared without case, and by where they sit: "Fish" inside Kacha bazar is
/// not "Fish" inside Food. A category the person archived counts as there, and
/// so does everything that would go inside it, so none of it comes back.
/// Nothing that exists is changed.
List<PlannedCategory> missingDefaults(
  Iterable<Category> existing, {
  List<DefaultCategory> expense = defaultExpenseCategories,
  List<DefaultCategory> income = defaultIncomeCategories,
}) {
  final all = existing.toList();
  final byId = {for (final c in all) c.id: c};
  final planned = <PlannedCategory>[];

  void plan(CategoryType type, List<DefaultCategory> defaults) {
    final found = <String, Category>{};
    for (final category in all.where((c) => c.type == type)) {
      found.putIfAbsent(pathKey(pathOf(category, byId)), () => category);
    }
    final archived = <String>[];

    for (final entry in flattenDefaults(defaults)) {
      final key = pathKey(entry.path);
      if (archived.any((prefix) => key.startsWith(prefix))) continue;
      final there = found[key];
      if (there == null) {
        planned.add(
          PlannedCategory(
            type: type,
            name: entry.name,
            icon: entry.icon,
            color: entry.color,
            parentPath: entry.parentPath,
          ),
        );
      } else if (there.isArchived) {
        // The separator keeps "Food" from catching "Foodstuff".
        archived.add('$key\u0000');
      }
    }
  }

  plan(CategoryType.expense, expense);
  plan(CategoryType.income, income);
  return planned;
}
