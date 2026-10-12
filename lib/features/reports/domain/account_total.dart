/// What came in and went out of one account in a period, in poisha. Transfers
/// and balance corrections are not counted.
class AccountTotal {
  const AccountTotal({
    required this.accountId,
    required this.name,
    required this.income,
    required this.expense,
  });

  final int accountId;
  final String name;
  final int income;
  final int expense;
}
