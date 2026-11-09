import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Someone paid a bill for me: it is my expense and I owe it, and no money
/// touched my accounts.
///
/// A transaction needs an account, so the money borrowed comes into
/// [record]'s account as a correction and the expense goes out of it. They
/// cancel, and the balance stays as it was.
class PaidForMe {
  PaidForMe(AppDatabase db)
    : _db = db,
      _debts = DebtsRepository(db),
      _transactions = TransactionsRepository(db);

  final AppDatabase _db;
  final DebtsRepository _debts;
  final TransactionsRepository _transactions;

  /// Saves the loan and the expense, or neither. Returns the loan's id.
  Future<int> record({
    required String person,
    required int amount,
    required int accountId,
    required int categoryId,
    required DateTime date,
    DateTime? dueOn,
    String note = '',
  }) {
    return _db.transaction(() async {
      final debtId = await _debts.createDebt(
        person: person,
        direction: DebtDirection.borrowed,
        amount: amount,
        openedOn: date,
        dueOn: dueOn,
        note: note,
        accountId: accountId,
      );
      await _transactions.addTransaction(
        TransactionInput(
          type: TransactionType.expense,
          amount: amount,
          accountId: accountId,
          categoryId: categoryId,
          date: date,
          note: note.trim().isEmpty ? 'Paid by ${person.trim()}' : note.trim(),
        ),
      );
      return debtId;
    });
  }
}
