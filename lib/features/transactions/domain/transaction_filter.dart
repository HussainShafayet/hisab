import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The options of the filter sheet that can be taken off one by one, from the
/// chips under the app bar. The date range has its own banner.
enum FilterOption { type, category, account, amount, tag, feeling }

/// Narrows the transaction list. A null or empty field means "any".
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.type,
    this.categoryId,
    this.categoryScope = const {},
    this.accountId,
    this.range,
    this.minAmount,
    this.maxAmount,
    this.tagId,
    this.feeling,
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

  /// The smallest and the largest amount to show, in poisha, both included.
  /// Either may be left out.
  final int? minAmount;
  final int? maxAmount;

  /// The trip or event (tag) the transactions belong to.
  final int? tagId;

  /// How the spending felt (needed, wanted, regret).
  final Feeling? feeling;

  /// Whether anything is narrowing the list. A search text counts.
  bool get isActive =>
      query.trim().isNotEmpty ||
      type != null ||
      categoryId != null ||
      accountId != null ||
      range != null ||
      hasAmountRange ||
      tagId != null ||
      feeling != null;

  bool get hasAmountRange => minAmount != null || maxAmount != null;

  /// How many of the options in the filter sheet are set (the search text is
  /// not one of them: it has its own field).
  int get sheetOptionCount =>
      [
        type,
        categoryId,
        accountId,
        range,
        tagId,
        feeling,
      ].where((option) => option != null).length +
      (hasAmountRange ? 1 : 0);

  TransactionFilter withQuery(String query) => TransactionFilter(
    query: query,
    type: type,
    categoryId: categoryId,
    categoryScope: categoryScope,
    accountId: accountId,
    range: range,
    minAmount: minAmount,
    maxAmount: maxAmount,
    tagId: tagId,
    feeling: feeling,
  );

  /// The options of the filter sheet that are set, in the order of the sheet.
  List<FilterOption> get activeOptions => [
    if (type != null) FilterOption.type,
    if (categoryId != null) FilterOption.category,
    if (accountId != null) FilterOption.account,
    if (hasAmountRange) FilterOption.amount,
    if (tagId != null) FilterOption.tag,
    if (feeling != null) FilterOption.feeling,
  ];

  /// The same filter without [option]. The search text and the date range are
  /// kept.
  TransactionFilter without(FilterOption option) => TransactionFilter(
    query: query,
    range: range,
    type: option == FilterOption.type ? null : type,
    categoryId: option == FilterOption.category ? null : categoryId,
    categoryScope: option == FilterOption.category ? const {} : categoryScope,
    accountId: option == FilterOption.account ? null : accountId,
    minAmount: option == FilterOption.amount ? null : minAmount,
    maxAmount: option == FilterOption.amount ? null : maxAmount,
    tagId: option == FilterOption.tag ? null : tagId,
    feeling: option == FilterOption.feeling ? null : feeling,
  );

  /// The same filter without the custom date range.
  TransactionFilter withoutRange() => TransactionFilter(
    query: query,
    type: type,
    categoryId: categoryId,
    categoryScope: categoryScope,
    accountId: accountId,
    minAmount: minAmount,
    maxAmount: maxAmount,
    tagId: tagId,
    feeling: feeling,
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
    if (filter.minAmount != null && item.amount < filter.minAmount!) {
      return false;
    }
    if (filter.maxAmount != null && item.amount > filter.maxAmount!) {
      return false;
    }
    if (filter.tagId != null && item.tagId != filter.tagId) return false;
    if (filter.feeling != null && item.feeling != filter.feeling) return false;
    if (text.isEmpty) return true;
    return item.note.toLowerCase().contains(text) ||
        (item.categoryName?.toLowerCase().contains(text) ?? false) ||
        poishaToInput(item.amount).contains(text);
  }

  return items.where(matches).toList();
}
