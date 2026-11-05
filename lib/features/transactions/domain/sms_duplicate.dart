import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// An entry in [sameDay] that looks like the one a pasted SMS would make: the
/// same kind, amount and account. For messages without a transaction id (a
/// bank's), and for when the note that held the id was edited. Balance
/// corrections are not entries of the person's and never match.
TransactionItem? sameEntryAs(
  Iterable<TransactionItem> sameDay, {
  required TransactionType type,
  required int amount,
  required int? accountId,
}) {
  if (accountId == null) return null;
  for (final item in sameDay) {
    if (item.isAdjustment) continue;
    if (item.type == type &&
        item.amount == amount &&
        item.accountId == accountId) {
      return item;
    }
  }
  return null;
}
