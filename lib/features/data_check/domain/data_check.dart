import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Two copies of one entry are only suspect from this amount (৳500, in
/// poisha): rickshaw twice in a day for ৳20 is a day, not a mistake.
const duplicateMinAmount = 50000;

/// An expense is unusually large when it is at least this many times the usual
/// (median) one of its category...
const largeFactor = 10;

/// ...and at least ৳1,000 (poisha)...
const largeMinAmount = 100000;

/// ...and the category has at least this many entries to tell what is usual.
const largeMinEntries = 8;

/// The most of each kind that is listed.
const maxListed = 20;

/// Entries that look like the same one entered more than once: the same day,
/// kind, amount, account and note.
class DuplicateGroup {
  const DuplicateGroup(this.items);

  /// Two or more, the oldest entered first. The first is the one to keep.
  final List<TransactionItem> items;

  int get extra => items.length - 1;
}

/// Two categories with names that look alike, such as "Utility" and "Utilities".
class SimilarCategories {
  const SimilarCategories(this.first, this.second);

  final Category first;
  final Category second;
}

/// What sits in "Other" and "Other income": spending nobody named.
class OtherSummary {
  const OtherSummary({
    required this.count,
    required this.total,
    required this.items,
  });

  final int count;

  /// In poisha.
  final int total;

  /// The biggest, biggest first, at most [maxListed].
  final List<TransactionItem> items;
}

/// What looks wrong, or worth a look, in the entries.
class DataCheck {
  const DataCheck({
    this.duplicates = const [],
    this.futureDated = const [],
    this.unusuallyLarge = const [],
    this.other,
    this.similarCategories = const [],
  });

  final List<DuplicateGroup> duplicates;

  /// Dated after today, the soonest first.
  final List<TransactionItem> futureDated;

  /// Expenses far above what is usual for their category, biggest first.
  final List<TransactionItem> unusuallyLarge;

  final OtherSummary? other;
  final List<SimilarCategories> similarCategories;

  /// How many things there are to look at, in all.
  int get findings =>
      duplicates.length +
      futureDated.length +
      unusuallyLarge.length +
      (other == null ? 0 : 1) +
      similarCategories.length;

  bool get isClean => findings == 0;
}

/// Looks through [transactions] and [categories] (the ones in use) for things
/// to look at. A balance correction is not an entry of the person's and is
/// left out. Nothing is changed.
DataCheck checkData({
  required List<TransactionItem> transactions,
  required List<Category> categories,
  required DateTime now,
}) {
  final real = [
    for (final item in transactions)
      if (!item.isAdjustment) item,
  ];

  return DataCheck(
    duplicates: _duplicates(real),
    futureDated: _futureDated(real, now),
    unusuallyLarge: _unusuallyLarge(real),
    other: _other(real),
    similarCategories: _similarCategories(categories),
  );
}

List<DuplicateGroup> _duplicates(List<TransactionItem> items) {
  final groups = <String, List<TransactionItem>>{};
  for (final item in items) {
    if (item.amount < duplicateMinAmount) continue;
    final day = dateOnly(item.date);
    final key =
        '${day.year}-${day.month}-${day.day}|${item.type.name}|${item.amount}|'
        '${item.accountId}|${item.toAccountId ?? ''}|${normalizeName(item.note)}';
    groups.putIfAbsent(key, () => []).add(item);
  }
  final found = [
    for (final group in groups.values)
      if (group.length >= 2)
        DuplicateGroup([...group]..sort((a, b) => a.id.compareTo(b.id))),
  ]..sort((a, b) => b.items.first.date.compareTo(a.items.first.date));
  return found;
}

List<TransactionItem> _futureDated(List<TransactionItem> items, DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return [
    for (final item in items)
      if (!item.date.isBefore(tomorrow)) item,
  ]..sort((a, b) => a.date.compareTo(b.date));
}

List<TransactionItem> _unusuallyLarge(List<TransactionItem> items) {
  final byCategory = <int, List<TransactionItem>>{};
  for (final item in items) {
    final category = item.categoryId;
    if (item.type != TransactionType.expense || category == null) continue;
    byCategory.putIfAbsent(category, () => []).add(item);
  }
  final large = <TransactionItem>[];
  for (final group in byCategory.values) {
    if (group.length < largeMinEntries) continue;
    final amounts = [for (final item in group) item.amount]..sort();
    final usual = amounts[amounts.length ~/ 2];
    final limit = usual * largeFactor;
    for (final item in group) {
      if (item.amount >= limit && item.amount >= largeMinAmount) {
        large.add(item);
      }
    }
  }
  large.sort((a, b) => b.amount.compareTo(a.amount));
  return large.take(maxListed).toList();
}

OtherSummary? _other(List<TransactionItem> items) {
  final names = {
    normalizeName(defaultExpenseCategoryName),
    normalizeName(defaultIncomeCategoryName),
  };
  final inOther = [
    for (final item in items)
      if (item.type != TransactionType.transfer &&
          item.categoryName != null &&
          names.contains(normalizeName(item.categoryName!)))
        item,
  ];
  if (inOther.isEmpty) return null;
  final total = inOther.fold<int>(0, (sum, item) => sum + item.amount);
  inOther.sort((a, b) => b.amount.compareTo(a.amount));
  return OtherSummary(
    count: inOther.length,
    total: total,
    items: inOther.take(maxListed).toList(),
  );
}

List<SimilarCategories> _similarCategories(List<Category> categories) {
  final active = [
    for (final category in categories)
      if (!category.isArchived) category,
  ];
  final existing = [
    for (final category in active)
      ExistingCategory(
        id: category.id,
        name: category.name,
        type: category.type,
        parentId: category.parentId,
      ),
  ];
  final byId = {for (final category in active) category.id: category};
  final seen = <String>{};
  final pairs = <SimilarCategories>[];
  for (final category in active) {
    final match = similarCategory(category.name, category.type, [
      for (final other in existing)
        if (other.id != category.id) other,
    ]);
    if (match == null) continue;
    final other = byId[match.id]!;
    // The same name under two groups is on purpose ("Gifts" of the wife and
    // of the children); a group and what is inside it belong together.
    if (normalizeName(category.name) == normalizeName(other.name)) continue;
    if (category.parentId == other.id || other.parentId == category.id) {
      continue;
    }
    final key = category.id < other.id
        ? '${category.id}-${other.id}'
        : '${other.id}-${category.id}';
    if (!seen.add(key)) continue;
    pairs.add(SimilarCategories(category, other));
  }
  return pairs.take(maxListed).toList();
}
