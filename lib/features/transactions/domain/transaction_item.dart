import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// A transaction together with the names the UI needs to show it.
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.accountName,
    required this.date,
    required this.note,
    required this.createdAt,
    this.toAccountId,
    this.toAccountName,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.categoryParentId,
  });

  final int id;
  final TransactionType type;

  /// In poisha, always positive. The sign comes from [type].
  final int amount;

  final int accountId;
  final String accountName;

  /// Transfers only.
  final int? toAccountId;
  final String? toAccountName;

  /// Null for transfers.
  final int? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;

  /// The parent of the category, when the category is a sub-category.
  final int? categoryParentId;

  /// Local time.
  final DateTime date;
  final String note;

  /// When the transaction was first saved. Kept so a deleted transaction can
  /// be restored exactly.
  final DateTime createdAt;
}
