import 'package:hishab/core/utils/money.dart';

/// What a mobile money or bank message says was done.
enum SmsKind {
  cashOut,
  cashIn,
  received,
  sent,
  payment,
  recharge,
  bill,
  debited,
}

/// What a pasted bKash, Nagad, Rocket, Upay or bank SMS says about one entry.
/// Only the amount and the kind are certain; the rest is null when the message
/// does not say it.
class SmsEntry {
  const SmsEntry({
    required this.kind,
    required this.amount,
    this.fee = 0,
    this.balance,
    this.trxId,
    this.counterparty,
    this.provider,
    this.date,
  });

  final SmsKind kind;

  /// In poisha, without the fee.
  final int amount;

  /// In poisha. Zero when the message has none.
  final int fee;

  /// What the message says is left in the account, in poisha.
  final int? balance;

  /// The transaction id the service gave (`TrxID`). The same message pasted
  /// twice has the same id, which is how it is told apart from a new one.
  final String? trxId;

  /// A phone number or a shop, whoever the money went to or came from.
  final String? counterparty;

  /// `bkash`, `nagad`, `rocket` or `upay` when the message names it.
  final String? provider;

  /// The day of the message, at midnight.
  final DateTime? date;

  /// Money came in.
  bool get isIncome => switch (kind) {
    SmsKind.cashIn || SmsKind.received => true,
    _ => false,
  };
}

final _money = RegExp(
  r'(?:(?<![A-Za-z])(?:tk|bdt|taka)\.?\s*:?\s*|৳\s*)(\d[\d,]*(?:\.\d{1,2})?)'
  r'|(\d[\d,]*(?:\.\d{1,2})?)\s*(?:tk|bdt|taka|৳)(?![A-Za-z])',
  caseSensitive: false,
);

final _trxId = RegExp(
  r'(?:trx\s*id|txn\s*id|trnx\s*id|transaction\s*id|ref(?:erence)?(?:\s*no)?)'
  r'\s*[:#]?\s*([A-Za-z0-9]{6,})',
  caseSensitive: false,
);

final _phone = RegExp(r'(?<!\d)(?:\+?88)?(01[3-9]\d{8})(?!\d)');

final _shop = RegExp(
  r"(?:\bto|\bfrom|\bat)\s+([A-Za-z][A-Za-z0-9 &'\-]{2,30}?)"
  r'(?=\s*(?:\.|,|\bon\b|\bfee\b|\bbal|\btrx|\busing\b|\bsuccessful|$))',
  caseSensitive: false,
);

final _numericDate = RegExp(
  r'(?<!\d)(\d{1,2})[/\-](\d{1,2})[/\-](\d{4}|\d{2})(?!\d)',
);
final _namedDate = RegExp(
  r'(?<!\d)(\d{1,2})[\s\-]([A-Za-z]{3})[A-Za-z]*[\s\-,]+(\d{4}|\d{2})(?!\d)',
);

const _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

/// Reads a pasted SMS of bKash, Nagad, Rocket, Upay or a bank. Null when it
/// is not a message about money moving: no amount, or nothing saying which way
/// it went. The messages are not all alike, so this looks for the words and
/// figures that every kind has, not for one fixed layout.
SmsEntry? parseSms(String text) {
  final lower = text.toLowerCase();
  final kind = _kindOf(lower);
  if (kind == null) return null;

  int? amount;
  var fee = 0;
  int? balance;
  var previousEnd = 0;
  for (final match in _money.allMatches(text)) {
    final figure = match.group(1) ?? match.group(2)!;
    final poisha = parseTakaToPoisha(figure);
    final from = match.start - previousEnd > 40
        ? match.start - 40
        : previousEnd;
    final before = text.substring(from, match.start).toLowerCase();
    previousEnd = match.end;
    if (poisha == null) continue;

    // "charge" alone: "recharge" is not a fee.
    if (RegExp(r'\b(fee|charges?)\b').hasMatch(before)) {
      fee = poisha;
    } else if (before.contains('bal') ||
        before.contains('limit') ||
        before.contains('outstanding')) {
      balance ??= poisha;
    } else if (before.contains('vat')) {
      continue;
    } else {
      amount ??= poisha;
    }
  }
  if (amount == null || amount <= 0) return null;

  final phone = _phone.firstMatch(text)?.group(1);
  return SmsEntry(
    kind: kind,
    amount: amount,
    fee: fee,
    balance: balance,
    trxId: _trxId.firstMatch(text)?.group(1),
    counterparty: phone ?? _shop.firstMatch(text)?.group(1)?.trim(),
    provider: _providerOf(lower),
    date: _dateOf(text),
  );
}

SmsKind? _kindOf(String t) {
  if (t.contains('cash out') ||
      t.contains('cashout') ||
      t.contains('withdraw')) {
    return SmsKind.cashOut;
  }
  if (t.contains('cash in') || t.contains('cashin')) return SmsKind.cashIn;
  if (t.contains('refund') ||
      t.contains('cashback') ||
      RegExp(r'\b(received|credited|deposited|deposit|add money)\b')
          .hasMatch(t)) {
    return SmsKind.received;
  }
  if (t.contains('recharge')) return SmsKind.recharge;
  if (t.contains('bill')) return SmsKind.bill;
  if (t.contains('send money') ||
      RegExp(r'\b(sent|transferred|transfer)\b').hasMatch(t)) {
    return SmsKind.sent;
  }
  if (RegExp(r'\b(payment|paid|purchase|purchased|spent)\b').hasMatch(t)) {
    return SmsKind.payment;
  }
  if (t.contains('debited')) return SmsKind.debited;
  return null;
}

String? _providerOf(String t) {
  for (final name in const ['bkash', 'nagad', 'rocket', 'upay']) {
    if (t.contains(name)) return name;
  }
  return null;
}

DateTime? _dateOf(String text) {
  final numeric = _numericDate.firstMatch(text);
  if (numeric != null) {
    return _day(
      int.parse(numeric.group(1)!),
      int.parse(numeric.group(2)!),
      numeric.group(3)!,
    );
  }
  final named = _namedDate.firstMatch(text);
  if (named != null) {
    final month = _months.indexOf(named.group(2)!.toLowerCase()) + 1;
    if (month > 0) {
      return _day(int.parse(named.group(1)!), month, named.group(3)!);
    }
  }
  return null;
}

DateTime? _day(int day, int month, String year) {
  final y = year.length == 2 ? 2000 + int.parse(year) : int.parse(year);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(y, month, day);
  // 31 February rolls over into March: that is not a date.
  return date.month == month ? date : null;
}
