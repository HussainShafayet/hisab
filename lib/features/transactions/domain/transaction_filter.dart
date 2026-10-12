import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Narrows the transaction list. A null or empty field means "any".
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.type,
    this.categoryId,
    this.categoryScope = const {},
    this.accountId,
    this.range,
  });

  /// Matched against the note, the category name and the amount.
  final String query;
  final TransactionType? type;

  /// The category chosen. It matches the transactions of the category and of
  /// everything inside it, which [categoryScope] lists.
  final int? categoryId;

  /// The ids of [categoryId] and every category inside it, at any depth. When
  /// empty, the category and its direct sub-categories match.
  final Set<int> categoryScope;

  /// Matches transactions from or to this account (transfers included).
  final int? accountId;

  /// A custom date range. When set it replaces the month being browsed.
  final DateRange? range;

  /// Whether anything is narrowing the list. A search text counts.
  bool get isActive =>
      query.trim().isNotEmpty ||
      type != null ||
      categoryId != null ||
      accountId != null ||
      range != null;

  /// How many of the options in the filter sheet are set (the search text is
  /// not one of them: it has its own field).
  int get sheetOptionCount => [
    type,
    categoryId,
    accountId,
    range,
  ].where((option) => option != null).length;

  TransactionFilter withQuery(String query) => TransactionFilter(
    query: query,
    type: type,
    categoryId: categoryId,
    categoryScope: categoryScope,
    accountId: accountId,
    range: range,
  );

  /// The same filter without the custom date range.
  TransactionFilter withoutRange() => TransactionFilter(
    query: query,
    type: type,
    categoryId: categoryId,
    categoryScope: categoryScope,
    accountId: accountId,
  );

  /// The same filter without the options of the filter sheet.
  TransactionFilter withoutSheetOptions() => TransactionFilter(query: query);
}

/// The items that match [filter], in their original order.
List<TransactionItem> applyTransactionFilter(
  Iterable<TransactionItem> items,
  TransactionFilter filter,
) {
  final text = filter.query.trim().toLowerCase().replaceAll(',', '');
  final range = filter.range;

  bool inCategory(TransactionItem item) {
    if (filter.categoryScope.isNotEmpty) {
      return filter.categoryScope.contains(item.categoryId);
    }
    return item.categoryId == filter.categoryId ||
        item.categoryParentId == filter.categoryId;
  }

  bool matches(TransactionItem item) {
    if (filter.type != null && item.type != filter.type) return false;
    if (filter.categoryId != null && !inCategory(item)) return false;
    if (filter.accountId != null &&
        item.accountId != filter.accountId &&
        item.toAccountId != filter.accountId) {
      return false;
    }
    if (range != null &&
        (item.date.isBefore(range.start) || !item.date.isBefore(range.end))) {
      return false;
    }
    if (text.isEmpty) return true;
    return item.note.toLowerCase().contains(text) ||
        (item.categoryName?.toLowerCase().contains(text) ?? false) ||
        poishaToInput(item.amount).contains(text);
  }

  return items.where(matches).toList();
}
