import 'package:hishab/features/accounts/domain/account_type.dart';

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.includeInTotal,
    required this.isArchived,
    this.creditLimit,
    this.billDueDay,
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

  /// A credit card's limit in poisha, when one was set.
  final int? creditLimit;

  /// The day of the month a credit card's bill is due (1 to 31), if set.
  final int? billDueDay;

  bool get isCreditCard => type == AccountType.creditCard;
}

/// An [Account] together with its current balance in poisha.
class AccountWithBalance {
  const AccountWithBalance({required this.account, required this.balance});

  final Account account;
  final int balance;
}
