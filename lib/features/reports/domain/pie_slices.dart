import 'package:hishab/features/reports/domain/category_total.dart';

/// One slice of the category pie chart.
class PieSlice {
  const PieSlice({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.categoryId,
  });

  final String label;

  /// In poisha.
  final int amount;
  final int color;
  final String icon;

  /// Null for the "Others" slice.
  final int? categoryId;

  bool get isOthers => categoryId == null;
}

/// The slices for a pie chart: the biggest [maxSlices] categories as they
/// are, and everything smaller together as one "Others" slice. [totals] must
/// be sorted biggest first. Categories with nothing spent are left out.
List<PieSlice> buildPieSlices(
  List<CategoryTotal> totals, {
  int maxSlices = 6,
  int othersColor = 0xFF9E9E9E,
}) {
  final spent = totals.where((c) => c.total > 0).toList();
  PieSlice slice(CategoryTotal c) => PieSlice(
    label: c.name,
    amount: c.total,
    color: c.color,
    icon: c.icon,
    categoryId: c.categoryId,
  );

  // A single leftover category is shown as itself, not as "Others".
  if (spent.length <= maxSlices + 1) return spent.map(slice).toList();

  final rest = spent.skip(maxSlices);
  return [
    ...spent.take(maxSlices).map(slice),
    PieSlice(
      label: 'Others',
      amount: rest.fold(0, (sum, c) => sum + c.total),
      color: othersColor,
      icon: 'more_horiz',
    ),
  ];
}
