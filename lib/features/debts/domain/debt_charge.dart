/// What an extra amount added to a loan I took was for.
enum DebtChargeKind {
  /// It was not paid back in time.
  lateFee('Late fee'),

  /// Charged on what was left unpaid.
  interest('Loan interest'),

  /// A fee for the service, like a processing or bank charge.
  serviceCharge('Bank charge'),

  other('Other charge');

  const DebtChargeKind(this.category);

  /// The (English) name of the expense category the charge is kept in, when it
  /// counts as an expense.
  final String category;
}

/// An amount added to what is owed on a loan I took, in poisha.
class DebtCharge {
  const DebtCharge({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.chargedOn,
    required this.kind,
    required this.note,
    required this.isExpense,
  });

  final int id;
  final int debtId;

  /// Above zero.
  final int amount;
  final DateTime chargedOn;
  final DebtChargeKind kind;
  final String note;

  /// It also went in as my expense (an entry in a fee category).
  final bool isExpense;
}
