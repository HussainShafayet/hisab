import 'package:hishab/features/accounts/domain/account_type.dart';

class DefaultAccount {
  const DefaultAccount(this.name, this.type);

  final String name;
  final AccountType type;
}

/// Created once, when the database is first created. Edit freely: existing
/// installs are not affected, and every account can be renamed or archived in
/// the app. Opening balances start at 0 and are set in the app.
const defaultAccounts = [
  DefaultAccount('Cash', AccountType.cash),
  DefaultAccount('bKash', AccountType.mobileBanking),
  DefaultAccount('Nagad', AccountType.mobileBanking),
  DefaultAccount('Bank', AccountType.bank),
];
