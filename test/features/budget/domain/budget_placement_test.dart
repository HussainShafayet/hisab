import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/budget_placement.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

Category _c(int id, String name, [int? parentId]) => Category(
  id: id,
  name: name,
  type: CategoryType.expense,
  parentId: parentId,
  icon: 'category',
  color: 0xFF9E9E9E,
  isArchived: false,
  sortOrder: 0,
);

void main() {
  final byId = {
    for (final c in [
      _c(1, 'Family & gifts'),
      _c(2, 'In-laws', 1),
      _c(3, 'Gifts', 2),
      _c(4, 'Brothers & sisters', 1),
      _c(5, 'Gifts', 4),
      _c(6, 'Rent'),
    ])
      c.id: c,
  };

  test('a top-level category has no path and is counted nowhere else', () {
    final placement = budgetPlacement(6, byId, {6});
    expect(placement.parentPath, isNull);
    expect(placement.countedIn, isNull);
  });

  test('two budgets with the same name show different paths', () {
    expect(
      budgetPlacement(3, byId, {3, 5}).parentPath,
      'Family & gifts › In-laws',
    );
    expect(
      budgetPlacement(5, byId, {3, 5}).parentPath,
      'Family & gifts › Brothers & sisters',
    );
  });

  test('names the nearest category above that has its own budget', () {
    expect(budgetPlacement(3, byId, {1, 3}).countedIn, 'Family & gifts');
    expect(budgetPlacement(3, byId, {1, 2, 3}).countedIn, 'In-laws');
    expect(budgetPlacement(3, byId, {3}).countedIn, isNull);
  });

  test('an unknown category gives an empty placement', () {
    final placement = budgetPlacement(99, byId, {99});
    expect(placement.parentPath, isNull);
    expect(placement.countedIn, isNull);
  });

  test('adds up the limits of the budgets right inside each one', () {
    final placements = budgetPlacements({
      1: 100000,
      2: 60000,
      3: 50000,
      5: 20000,
    }, byId);
    // In-laws (60k) and Gifts of brothers (20k) sit right inside Family.
    expect(placements[1]!.insideLimits, 80000);
    expect(placements[1]!.insideOver(100000), isFalse);
    // Gifts of in-laws (50k) sits inside In-laws only.
    expect(placements[2]!.insideLimits, 50000);
    expect(placements[3]!.insideLimits, 0);
    expect(placements[3]!.countedIn, 'In-laws');
  });

  test('says when the budgets inside ask for more than the limit', () {
    final placements = budgetPlacements({1: 50000, 3: 40000, 5: 20000}, byId);
    expect(placements[1]!.insideLimits, 60000);
    expect(placements[1]!.insideOver(50000), isTrue);
  });
}
