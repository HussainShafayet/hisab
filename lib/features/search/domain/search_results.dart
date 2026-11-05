import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';

/// What one search finds, grouped by what it is.
class SearchResults {
  const SearchResults({
    this.transactions = const [],
    this.moreTransactions = 0,
    this.accounts = const [],
    this.categories = const [],
    this.loans = const [],
  });

  /// The newest matching transactions, up to the limit asked for.
  final List<TransactionItem> transactions;

  /// How many more matched than are listed.
  final int moreTransactions;
  final List<AccountWithBalance> accounts;
  final List<Category> categories;
  final List<DebtItem> loans;

  bool get isEmpty =>
      transactions.isEmpty &&
      accounts.isEmpty &&
      categories.isEmpty &&
      loans.isEmpty;
}

/// How many transactions a search lists.
const searchTransactionLimit = 20;

bool _has(String text, String needle) => text.toLowerCase().contains(needle);

/// Looks for [query] in the notes, categories and amounts of [transactions],
/// the names of [accounts] and [categories] (with where they sit), and the
/// people and notes of [loans]. A query under two letters finds nothing: it
/// would match everything.
SearchResults searchAll(
  String query, {
  required Iterable<TransactionItem> transactions,
  required Iterable<AccountWithBalance> accounts,
  required Iterable<Category> categories,
  required Iterable<DebtItem> loans,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.length < 2) return const SearchResults();

  final matched =
      applyTransactionFilter(
          transactions,
          TransactionFilter(query: query),
        ).where((item) => !item.isAdjustment).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final all = categories.toList();
  final byId = {for (final c in all) c.id: c};
  return SearchResults(
    transactions: matched.take(searchTransactionLimit).toList(),
    moreTransactions: matched.length > searchTransactionLimit
        ? matched.length - searchTransactionLimit
        : 0,
    accounts: [
      for (final item in accounts)
        if (_has(item.account.name, needle)) item,
    ],
    categories: [
      for (final category in all)
        if (!category.isArchived &&
            _has(categoryPathLabel(category, byId), needle))
          category,
    ],
    loans: [
      for (final item in loans)
        if (_has(item.debt.person, needle) || _has(item.debt.note, needle))
          item,
    ],
  );
}
