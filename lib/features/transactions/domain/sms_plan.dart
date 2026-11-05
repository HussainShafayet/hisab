import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/transactions/domain/sms_entry.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// How the account of a pasted SMS was found, so the form can say how sure it
/// is.
enum SmsAccountSource {
  /// The message names its service and an account has that name.
  named,

  /// The person picked this account for the same kind of message before.
  remembered,

  /// The last digits of the A/C in the message are in an account's name.
  matched,

  /// The only account of the kind the message is about.
  onlyOne,

  /// Nothing tells: the form keeps its own account and the person must check.
  unknown,
}

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
    this.accountSource = SmsAccountSource.unknown,
    this.walletId,
    this.walletIsTo = false,
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

  /// How [accountId] (or the wallet side of a transfer) was found.
  final SmsAccountSource accountSource;

  /// The account of the service or bank the message came from. For a cash in
  /// it is the transfer's [toAccountId].
  final int? walletId;
  final bool walletIsTo;
}

/// Decides how [sms] fills the form: which type, which accounts, what amount.
/// The account of the service is found, in this order, by its name in an
/// account's name, by what the person picked for the same kind of message
/// before ([remembered], by [SmsEntry.source]), by the digits of the A/C, and
/// last as the only account of the kind (mobile banking, or bank for a bank
/// message). A cash out or cash in becomes a transfer between that account and
/// cash, with the fee, when both exist; otherwise it is plain spending or
/// income. [currentAccountId] is the form's account, for the balance check of
/// a bank message.
SmsPlan planSms(
  SmsEntry sms,
  List<Account> accounts, {
  int? currentAccountId,
  Map<String, int> remembered = const {},
}) {
  Account? only(AccountType type) {
    final ofType = accounts.where((a) => a.type == type).toList();
    return ofType.length == 1 ? ofType.single : null;
  }

  final provider = sms.provider;
  final preferBank = sms.kind == SmsKind.debited || sms.bankLike;

  (Account?, SmsAccountSource) find() {
    if (provider != null) {
      final named = accounts
          .where((a) => a.name.toLowerCase().contains(provider))
          .firstOrNull;
      if (named != null) return (named, SmsAccountSource.named);
    }
    final rememberedId = sms.source == null ? null : remembered[sms.source];
    if (rememberedId != null) {
      final picked = accounts.where((a) => a.id == rememberedId).firstOrNull;
      if (picked != null) return (picked, SmsAccountSource.remembered);
    }
    final digits = sms.accountHint;
    if (digits != null) {
      final matched = accounts
          .where((a) => a.name.contains(digits))
          .firstOrNull;
      if (matched != null) return (matched, SmsAccountSource.matched);
    }
    final single = preferBank
        ? only(AccountType.bank)
        : only(AccountType.mobileBanking);
    if (single != null) return (single, SmsAccountSource.onlyOne);
    return (null, SmsAccountSource.unknown);
  }

  final (wallet, source) = find();
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
        accountSource: source,
        walletId: wallet.id,
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
        accountSource: source,
        walletId: wallet.id,
        walletIsTo: true,
      );
    case SmsKind.cashIn || SmsKind.received:
      return SmsPlan(
        type: TransactionType.income,
        amount: sms.amount,
        accountId: wallet?.id,
        balanceAccountId: walletId,
        balanceChange: sms.amount - sms.fee,
        accountSource: source,
        walletId: wallet?.id,
      );
    default:
      final spent = sms.amount + sms.fee;
      return SmsPlan(
        type: TransactionType.expense,
        amount: spent,
        accountId: wallet?.id,
        balanceAccountId: walletId,
        balanceChange: -spent,
        accountSource: source,
        walletId: wallet?.id,
      );
  }
}
