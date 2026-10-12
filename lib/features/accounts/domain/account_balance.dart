import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Everything that ever moved through one account, in poisha (all >= 0).
class AccountFlows {
  const AccountFlows({
    this.income = 0,
    this.expense = 0,
    this.transferOut = 0,
    this.transferIn = 0,
  });

  /// Income transactions recorded on this account.
  final int income;

  /// Expense transactions recorded on this account (transfer fees included,
  /// they are saved as expenses).
  final int expense;

  /// Transfers that left this account.
  final int transferOut;

  /// Transfers that arrived in this account.
  final int transferIn;
}

/// Current balance = opening balance + income - expense - transfers out
/// + transfers in.
int calculateAccountBalance({
  required int openingBalance,
  required AccountFlows flows,
}) {
  return openingBalance +
      flows.income -
      flows.expense -
      flows.transferOut +
      flows.transferIn;
}

/// The "total balance": the sum over accounts that are active and not
/// excluded with "include in total". Archived accounts are left out even if
/// they still hold money.
int calculateTotalBalance(Iterable<AccountWithBalance> accounts) {
  var total = 0;
  for (final item in accounts) {
    if (item.account.includeInTotal && !item.account.isArchived) {
      total += item.balance;
    }
  }
  return total;
}

/// The transaction needed to make an account's balance match reality.
class BalanceAdjustment {
  const BalanceAdjustment({required this.type, required this.amount});

  /// Income when the real balance is higher, expense when it is lower.
  final TransactionType type;

  /// In poisha, always positive.
  final int amount;
}

/// Null when [current] already equals [target].
BalanceAdjustment? calculateBalanceAdjustment({
  required int current,
  required int target,
}) {
  final difference = target - current;
  if (difference == 0) return null;
  return BalanceAdjustment(
    type: difference > 0 ? TransactionType.income : TransactionType.expense,
    amount: difference.abs(),
  );
}

/// How much of the total balance is in each kind of account (cash, mobile
/// banking, bank, card). Counts the same accounts as [calculateTotalBalance],
/// so the parts add up to the total. A kind with no counted account is left
/// out.
Map<AccountType, int> totalByAccountType(
  Iterable<AccountWithBalance> accounts,
) {
  final totals = <AccountType, int>{};
  for (final item in accounts) {
    if (item.account.includeInTotal && !item.account.isArchived) {
      totals.update(
        item.account.type,
        (sum) => sum + item.balance,
        ifAbsent: () => item.balance,
      );
    }
  }
  return totals;
}
