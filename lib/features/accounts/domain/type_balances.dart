import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

/// What the accounts of one kind (cash, bank, bKash...) hold together.
class TypeBalance {
  const TypeBalance({
    required this.type,
    required this.total,
    required this.count,
  });

  final AccountType type;

  /// In poisha. A credit card counts as what is owed, so it is negative.
  final int total;
  final int count;
}

/// The balance of each kind of account, in the order of [AccountType]. Kinds
/// with no account are left out, and so are accounts that do not count in the
/// total or have no balance yet.
List<TypeBalance> balancesByType(
  Iterable<Account> accounts,
  Map<int, int> balances,
) {
  final totals = <AccountType, int>{};
  final counts = <AccountType, int>{};
  for (final account in accounts) {
    final balance = balances[account.id];
    if (balance == null || account.isArchived) continue;
    totals[account.type] = (totals[account.type] ?? 0) + balance;
    counts[account.type] = (counts[account.type] ?? 0) + 1;
  }
  return [
    for (final type in AccountType.values)
      if (totals.containsKey(type))
        TypeBalance(type: type, total: totals[type]!, count: counts[type]!),
  ];
}
