import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What the "add transaction" form can choose from.
class AddTransactionOptions {
  const AddTransactionOptions({
    required this.accounts,
    required this.defaultAccountId,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  /// Active accounts only.
  final List<Account> accounts;

  /// The account used by the latest transaction, or the first account.
  /// Null when there are no accounts.
  final int? defaultAccountId;

  /// Active categories, most used first (sub-categories follow their parent
  /// when nothing was used yet).
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;

  List<Category> categoriesFor(TransactionType type) => switch (type) {
    TransactionType.expense => expenseCategories,
    TransactionType.income => incomeCategories,
    TransactionType.transfer => const [],
  };
}
