import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/categories/presentation/category_style.dart';

void main() {
  final seeded = [...defaultExpenseCategories, ...defaultIncomeCategories];

  test('every seeded category icon can be shown and picked', () {
    for (final category in seeded) {
      expect(
        categoryIcons.containsKey(category.icon),
        isTrue,
        reason: '${category.name} uses unknown icon "${category.icon}"',
      );
    }
  });

  test('every seeded category color is in the palette', () {
    for (final category in seeded) {
      expect(
        categoryColors,
        contains(category.color),
        reason: '${category.name} uses a color that cannot be picked',
      );
    }
    expect(categoryColors, contains(defaultCategoryColor));
  });

  test('the balance adjustment category has an icon', () {
    // AccountsRepository saves this category with the "tune" icon.
    expect(categoryIcons.containsKey('tune'), isTrue);
    expect(balanceAdjustmentCategoryName, isNotEmpty);
  });

  test('palette has no duplicate colors and icons are all distinct', () {
    expect(categoryColors.toSet(), hasLength(categoryColors.length));
    expect(categoryIcons.values.toSet(), hasLength(categoryIcons.length));
  });

  test('an unknown icon key falls back to the default icon', () {
    expect(categoryIconFor('does_not_exist'), Icons.category);
    expect(categoryIconFor('restaurant'), Icons.restaurant);
  });
}
