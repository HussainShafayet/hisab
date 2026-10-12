import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// How many categories the "frequently used" row of the picker shows.
const maxFrequentCategories = 6;

/// What the "add transaction" form can choose from.
class AddTransactionOptions {
  const AddTransactionOptions({
    required this.accounts,
    required this.defaultAccountId,
    required this.expenseCategories,
    required this.incomeCategories,
    this.frequentExpenseIds = const [],
    this.frequentIncomeIds = const [],
  });

  /// Active accounts only.
  final List<Account> accounts;

  /// The account used by the latest transaction, or the first account.
  /// Null when there are no accounts.
  final int? defaultAccountId;

  /// Active categories in tree order: each category is followed by the ones
  /// inside it, to any depth.
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;

  /// The ids of the categories used most in the last three months, most used
  /// first, at most [maxFrequentCategories]. Empty when nothing was used.
  final List<int> frequentExpenseIds;
  final List<int> frequentIncomeIds;

  List<Category> categoriesFor(TransactionType type) => switch (type) {
    TransactionType.expense => expenseCategories,
    TransactionType.income => incomeCategories,
    TransactionType.transfer => const [],
  };

  List<int> frequentIdsFor(TransactionType type) => switch (type) {
    TransactionType.expense => frequentExpenseIds,
    TransactionType.income => frequentIncomeIds,
    TransactionType.transfer => const [],
  };
}
