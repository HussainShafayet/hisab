/// What was spent in one top-level category (its sub-categories included).
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.total,
  });

  final int categoryId;
  final String name;

  /// Material icon key.
  final String icon;

  /// ARGB value.
  final int color;

  /// In poisha.
  final int total;
}
