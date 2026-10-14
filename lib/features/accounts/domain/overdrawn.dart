import 'package:hishab/features/accounts/domain/account.dart';

/// Whether an account holds less than nothing: money that is not there. A
/// credit card is left out, since owing is what a card does, and so is an
/// archived account, which is no longer in use.
bool isOverdrawn(AccountWithBalance item) =>
    !item.account.isCreditCard && !item.account.isArchived && item.balance < 0;

/// The accounts below zero, the deepest first.
List<AccountWithBalance> overdrawnAccounts(Iterable<AccountWithBalance> items) {
  final result = items.where(isOverdrawn).toList()
    ..sort((a, b) => a.balance.compareTo(b.balance));
  return result;
}
