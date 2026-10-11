import 'package:hishab/features/accounts/domain/account_type.dart';

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.includeInTotal,
    required this.isArchived,
  });

  final int id;
  final String name;
  final AccountType type;

  /// In poisha. May be negative.
  final int openingBalance;

  /// Whether this account counts towards the total balance.
  final bool includeInTotal;

  /// Archived accounts are hidden from lists but keep their transactions.
  final bool isArchived;
}

/// An [Account] together with its current balance in poisha.
class AccountWithBalance {
  const AccountWithBalance({required this.account, required this.balance});

  final Account account;
  final int balance;
}
