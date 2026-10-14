import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What the user entered for one transaction. The repository checks it and
/// saves it. An income or expense has a [categoryId] and no [toAccountId]; a
/// transfer has a [toAccountId] and no [categoryId].
class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.categoryId,
    this.note = '',
    this.usdAmount,
    this.tagId,
    this.feeling,
  });

  final TransactionType type;

  /// In poisha, must be above zero.
  final int amount;

  /// The account the money leaves (expense, transfer) or arrives in (income).
  final int accountId;

  final int? toAccountId;
  final int? categoryId;
  final DateTime date;
  final String note;

  /// In US cents, only for a credit card entry: the dollars spent (expense),
  /// refunded (income) or cleared by the payment (transfer into the card).
  final int? usdAmount;

  /// The trip or event of an income or expense. A transfer has none.
  final int? tagId;

  /// How an expense felt. Only an expense keeps it.
  final Feeling? feeling;
}
