import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/amount_calculator.dart';
import 'package:hishab/features/transactions/domain/quick_entry.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// One row of the "Add several" screen, as the person filled it in.
class BatchDraft {
  const BatchDraft({
    required this.type,
    required this.amountText,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.note = '',
  });

  final TransactionType type;

  /// What was typed in the amount field.
  final String amountText;

  /// The account the money leaves (expense, transfer) or arrives in (income).
  final int? accountId;
  final int? toAccountId;
  final int? categoryId;
  final String note;

  /// A row with no amount, no category and no note: nothing to save. The
  /// accounts do not count, since every new row starts with them filled in.
  bool get isBlank =>
      amountText.trim().isEmpty && note.trim().isEmpty && categoryId == null;
}

/// What a row turned into: the transaction to save, or why it cannot be saved
/// yet (in words for the person).
typedef BatchParse = ({TransactionInput? input, String? error});

/// Checks [draft] for what the person can fix on the screen itself, and turns
/// it into a transaction dated [date]. The other rules (an archived account,
/// a category of the wrong kind) are checked by the repository when the row
/// is saved.
BatchParse parseBatchDraft(BatchDraft draft, DateTime date) {
  final amount = evaluateAmount(draft.amountText);
  if (amount == null || amount <= 0) {
    return (input: null, error: tr('Enter an amount.'));
  }
  final accountId = draft.accountId;
  if (accountId == null) {
    return (input: null, error: tr('Choose an account.'));
  }

  final isTransfer = draft.type == TransactionType.transfer;
  final toAccountId = draft.toAccountId;
  final categoryId = draft.categoryId;
  if (isTransfer) {
    if (toAccountId == null) {
      return (input: null, error: tr('Choose the account the money goes to.'));
    }
    if (toAccountId == accountId) {
      return (input: null, error: tr('Choose two different accounts.'));
    }
  } else if (categoryId == null) {
    return (input: null, error: tr('Choose a category.'));
  }

  return (
    input: TransactionInput(
      type: draft.type,
      amount: amount,
      accountId: accountId,
      toAccountId: isTransfer ? toAccountId : null,
      categoryId: isTransfer ? null : categoryId,
      date: date,
      note: draft.note,
    ),
    error: null,
  );
}

/// The rows that a block of text makes, one for each line that says anything:
/// `rickshaw 50`, `lunch 120 bkash`, `+salary 30k`. Each line is read like the
/// quick-type line of the add form ([parseQuickEntry]); a line with no account
/// word uses [defaultAccountId]. A line with no amount still makes a row, for
/// the person to finish.
List<BatchDraft> draftsFromLines(
  String text,
  AddTransactionOptions options, {
  required int? defaultAccountId,
}) {
  final drafts = <BatchDraft>[];
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    if (line.trim().isEmpty) continue;
    final entry = parseQuickEntry(line, options);
    if (entry.isEmpty) continue;
    drafts.add(
      BatchDraft(
        type: entry.type,
        amountText: entry.amount == null ? '' : poishaToInput(entry.amount!),
        accountId: entry.account?.id ?? defaultAccountId,
        categoryId: entry.category?.id,
        note: entry.note,
      ),
    );
  }
  return drafts;
}
