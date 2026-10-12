import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What a transaction does to account balances: income adds to its account,
/// an expense takes from it, and a transfer takes from one account and adds to
/// another. A transfer's [fee] is saved as a separate expense on the account
/// the money leaves, so it comes off that account too.
class TransactionEffect {
  const TransactionEffect({
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.fee = 0,
  });

  final TransactionType type;

  /// In poisha, above zero.
  final int amount;
  final int accountId;

  /// The account a transfer goes to.
  final int? toAccountId;

  /// In poisha. Only a transfer has one.
  final int fee;

  /// How much the balance of [account] changes, in poisha (negative when
  /// money leaves it, zero when the transaction does not touch it).
  int changeFor(int account) {
    var change = 0;
    switch (type) {
      case TransactionType.income:
        if (account == accountId) change += amount;
      case TransactionType.expense:
        if (account == accountId) change -= amount;
      case TransactionType.transfer:
        if (account == accountId) change -= amount + fee;
        if (account == toAccountId) change += amount;
    }
    return change;
  }
}

/// The balance of [account] once [after] is saved. [current] is the balance
/// now. When an existing transaction is being edited, pass what it did as
/// [before]: it is taken back first, so the balance is not counted twice.
int projectedBalance({
  required int current,
  required int account,
  required TransactionEffect? after,
  TransactionEffect? before,
}) =>
    current -
    (before?.changeFor(account) ?? 0) +
    (after?.changeFor(account) ?? 0);
