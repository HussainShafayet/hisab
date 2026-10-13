/// A trip or event that transactions can be tagged with.
class Tag {
  const Tag({required this.id, required this.name});

  final int id;
  final String name;
}

/// A tag with what was spent and received under it. Transfers and balance
/// adjustments are not counted, as everywhere.
class TagSummary {
  const TagSummary({
    required this.tag,
    required this.expense,
    required this.income,
    required this.count,
    this.firstDate,
    this.lastDate,
  });

  final Tag tag;

  /// In poisha.
  final int expense;
  final int income;

  /// How many transactions carry the tag.
  final int count;

  /// The first and last day of those transactions (local), if any.
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// What it cost in all: spent less received.
  int get net => expense - income;
}

const maxTagNameLength = 40;
