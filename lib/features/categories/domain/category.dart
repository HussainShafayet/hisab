import 'package:hishab/features/categories/domain/category_type.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.parentId,
    required this.icon,
    required this.color,
    required this.isArchived,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final CategoryType type;

  /// Null for a top-level category. Sub-categories go one level deep only.
  final int? parentId;

  /// Material icon key, e.g. `restaurant`.
  final String icon;

  /// ARGB value.
  final int color;

  final bool isArchived;
  final int sortOrder;
}
