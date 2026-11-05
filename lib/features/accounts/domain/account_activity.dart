import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What came into an account and what went out of it over some transactions.
class AccountActivity {
  const AccountActivity({this.inflow = 0, this.outflow = 0, this.count = 0});

  /// In poisha: income and transfers in.
  final int inflow;

  /// In poisha: spending and transfers out.
  final int outflow;

  /// How many transactions touched the account.
  final int count;

  int get net => inflow - outflow;

  AccountActivity plus({int inflow = 0, int outflow = 0}) => AccountActivity(
    inflow: this.inflow + inflow,
    outflow: this.outflow + outflow,
    count: count + 1,
  );
}

/// The [AccountActivity] of every account that [items] touch. A transfer is
/// money out of one and into the other. Balance fixes are corrections, not
/// money moving, so they are left out, as in the totals everywhere else.
Map<int, AccountActivity> activityByAccount(Iterable<TransactionItem> items) {
  final result = <int, AccountActivity>{};
  void add(int account, {int inflow = 0, int outflow = 0}) {
    result[account] = (result[account] ?? const AccountActivity()).plus(
      inflow: inflow,
      outflow: outflow,
    );
  }

  for (final item in items) {
    if (item.isAdjustment) continue;
    switch (item.type) {
      case TransactionType.income:
        add(item.accountId, inflow: item.amount);
      case TransactionType.expense:
        add(item.accountId, outflow: item.amount);
      case TransactionType.transfer:
        add(item.accountId, outflow: item.amount);
        final to = item.toAccountId;
        if (to != null) add(to, inflow: item.amount);
    }
  }
  return result;
}

/// The transactions in [items] that touch [accountId], as the sender, the
/// receiver or the account the money is in.
List<TransactionItem> touching(
  Iterable<TransactionItem> items,
  int accountId,
) => [
  for (final item in items)
    if (item.accountId == accountId || item.toAccountId == accountId) item,
];
