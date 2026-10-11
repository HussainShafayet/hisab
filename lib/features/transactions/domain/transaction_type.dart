import 'package:hishab/features/categories/domain/category_type.dart';

/// Stored in the database by name: never rename a value without a migration.
/// The CHECK constraint in `transactions_table.dart` also mentions `transfer`.
enum TransactionType {
  income,
  expense,
  transfer;

  /// The kind of category this transaction uses, or null for a transfer,
  /// which has no category.
  CategoryType? get categoryType => switch (this) {
    TransactionType.income => CategoryType.income,
    TransactionType.expense => CategoryType.expense,
    TransactionType.transfer => null,
  };
}
