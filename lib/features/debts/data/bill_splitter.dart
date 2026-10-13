import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/split.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What splitting a bill made.
class SplitResult {
  const SplitResult({
    required this.mine,
    required this.debtIds,
    this.transactionId,
  });

  /// Your own part, in poisha.
  final int mine;

  /// The expense of your own part; null when you paid nothing for yourself.
  final int? transactionId;

  /// The loans made, one for each friend, in the order given.
  final List<int> debtIds;
}

/// Splits a bill you paid for friends: your own part is an expense, and each
/// friend's part is a loan to them. The account loses the whole [total], but
/// only your part counts as spending in budgets and reports.
class BillSplitter {
  BillSplitter(AppDatabase db)
    : _db = db,
      _debts = DebtsRepository(db),
      _transactions = TransactionsRepository(db);

  final AppDatabase _db;
  final DebtsRepository _debts;
  final TransactionsRepository _transactions;

  /// Saves it all or nothing. Your part is `total` less the friends' parts.
  Future<SplitResult> split({
    required int total,
    required int accountId,
    required int categoryId,
    required DateTime date,
    required List<SplitShare> friends,
    String title = '',
  }) {
    return _db.transaction(() async {
      if (total <= 0) {
        throw ValidationException(tr('The amount must be above zero.'));
      }
      if (friends.isEmpty) {
        throw ValidationException(tr('Add at least one friend.'));
      }
      if (friends.length > maxSplitFriends) {
        throw ValidationException(
          tr('A bill can be split with {max} friends at most.', {
            'max': maxSplitFriends,
          }),
        );
      }
      final names = <String>{};
      var theirs = 0;
      for (final friend in friends) {
        if (friend.person.trim().isEmpty) {
          throw ValidationException(tr('Every friend needs a name.'));
        }
        if (!names.add(friend.person.trim().toLowerCase())) {
          throw ValidationException(
            tr('{name} is there twice.', {'name': friend.person.trim()}),
          );
        }
        if (friend.amount <= 0) {
          throw ValidationException(
            tr('The part of {name} must be above zero.', {
              'name': friend.person.trim(),
            }),
          );
        }
        theirs += friend.amount;
      }
      final mine = total - theirs;
      if (mine < 0) {
        throw ValidationException(
          tr('The friends\' parts add up to more than the bill.'),
        );
      }

      final label = title.trim().isEmpty ? 'Split bill' : title.trim();
      int? transactionId;
      if (mine > 0) {
        transactionId = await _transactions.addTransaction(
          TransactionInput(
            type: TransactionType.expense,
            amount: mine,
            accountId: accountId,
            categoryId: categoryId,
            date: date,
            note: '$label (my part of ${formatPoisha(total)})',
          ),
        );
      }
      final debtIds = <int>[];
      for (final friend in friends) {
        debtIds.add(
          await _debts.createDebt(
            person: friend.person,
            direction: DebtDirection.lent,
            amount: friend.amount,
            openedOn: date,
            note: label,
            accountId: accountId,
          ),
        );
      }
      return SplitResult(
        mine: mine,
        transactionId: transactionId,
        debtIds: debtIds,
      );
    });
  }
}
