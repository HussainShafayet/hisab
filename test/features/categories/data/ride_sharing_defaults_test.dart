import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';

// Ride sharing is split by app (Pathao, Uber, Obhai, inDrive) and each app by
// the kind of vehicle (bike, car, CNG).

void main() {
  final entries = flattenDefaults(defaultExpenseCategories);
  final ride = ['Transport', 'City travel', 'Ride sharing'];

  List<String> inside(List<String> path) => [
    for (final e in entries)
      if (e.parentPath.length == path.length &&
          e.parentPath.join('>') == path.join('>'))
        e.name,
  ];

  test('Ride sharing has the apps of Bangladesh', () {
    expect(inside(ride), ['Pathao', 'Uber', 'Obhai', 'inDrive']);
  });

  test('each app has its kinds of vehicle', () {
    expect(inside([...ride, 'Pathao']), [
      'Pathao Bike',
      'Pathao Car',
      'Pathao CNG',
    ]);
    expect(inside([...ride, 'Uber']), ['Uber Moto', 'Uber Car']);
    expect(inside([...ride, 'Obhai']), ['Obhai Bike', 'Obhai Car']);
    expect(inside([...ride, 'inDrive']), [
      'inDrive Bike',
      'inDrive Car',
      'inDrive CNG',
    ]);
  });

  test('a vehicle is no deeper than the categories may go', () {
    final deepest = entries
        .where((e) => e.parentPath.contains('Ride sharing'))
        .map((e) => e.path.length)
        .reduce((a, b) => a > b ? a : b);

    expect(deepest, lessThanOrEqualTo(maxCategoryDepth));
  });

  test('no default is named twice inside one category', () {
    final seen = <String>{};
    for (final e in entries) {
      expect(seen.add(e.path.join('>')), isTrue, reason: e.path.join(' > '));
    }
  });
}
