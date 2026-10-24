import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/transactions/domain/sms_entry.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// How a pasted SMS fills the add form.
class SmsPlan {
  const SmsPlan({
    required this.type,
    required this.amount,
    this.accountId,
    this.toAccountId,
    this.transferFee = 0,
    this.balanceAccountId,
    this.balanceChange = 0,
  });

  final TransactionType type;

  /// In poisha. An expense includes the fee, because the fee left the
  /// account too.
  final int amount;

  /// The account the money leaves (or arrives in, for income). Null leaves
  /// the form's own choice.
  final int? accountId;

  /// A transfer's other account.
  final int? toAccountId;

  /// A transfer's fee, in poisha.
  final int transferFee;

  /// The account the SMS tells the balance of, and how much this entry moves
  /// it (in poisha, negative when money leaves).
  final int? balanceAccountId;
  final int balanceChange;
}

/// Decides how [sms] fills the form: which type, which accounts, what amount.
/// The service is found by its name in an account's name. A message that does
/// not name its service goes to the only mobile banking account, if there is
/// just one. A cash out or cash in becomes a transfer between that account and
/// cash, with the fee, when both exist; otherwise it is plain spending or
/// income. [currentAccountId] is the form's account, for the balance check of
/// a bank message.
SmsPlan planSms(SmsEntry sms, List<Account> accounts, {int? currentAccountId}) {
  Account? only(AccountType type) {
    final ofType = accounts.where((a) => a.type == type).toList();
    return ofType.length == 1 ? ofType.single : null;
  }

  final provider = sms.provider;
  final named = provider == null
      ? null
      : accounts
            .where((a) => a.name.toLowerCase().contains(provider))
            .firstOrNull;
  final wallet =
      named ??
      (sms.kind == SmsKind.debited
          ? only(AccountType.bank)
          : only(AccountType.mobileBanking));
  final cash = accounts.where((a) => a.type == AccountType.cash).firstOrNull;
  final walletId = wallet?.id ?? currentAccountId;

  final transfers = wallet != null && cash != null && wallet.id != cash.id;
  switch (sms.kind) {
    case SmsKind.cashOut when transfers:
      return SmsPlan(
        type: TransactionType.transfer,
        amount: sms.amount,
        accountId: wallet.id,
        toAccountId: cash.id,
        transferFee: sms.fee,
        balanceAccountId: wallet.id,
        balanceChange: -(sms.amount + sms.fee),
      );
    case SmsKind.cashIn when transfers:
      return SmsPlan(
        type: TransactionType.transfer,
        amount: sms.amount,
        accountId: cash.id,
        toAccountId: wallet.id,
        transferFee: sms.fee,
        balanceAccountId: wallet.id,
        balanceChange: sms.amount,
      );
    case SmsKind.cashIn || SmsKind.received:
      return SmsPlan(
        type: TransactionType.income,
        amount: sms.amount,
        accountId: wallet?.id,
        balanceAccountId: walletId,
        balanceChange: sms.amount - sms.fee,
      );
    default:
      final spent = sms.amount + sms.fee;
      return SmsPlan(
        type: TransactionType.expense,
        amount: spent,
        accountId: wallet?.id,
        balanceAccountId: walletId,
        balanceChange: -spent,
      );
  }
}
