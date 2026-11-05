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
    this.accountHint,
    this.source,
    this.bankLike = false,
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

  /// The last digits of the account or card the message names (`A/C
  /// XXXX1234` gives `1234`), for finding the person's account of that bank.
  final String? accountHint;

  /// What kind of sender this looks like, so the account the person picks once
  /// can be remembered for the next message of the same kind: the service name
  /// (`bkash`), the account digits (`ac1234`) or the style of its id label
  /// (`id-trxid`). Null when nothing tells.
  final String? source;

  /// The message is from a bank or about a card (an A/C number, an ATM), not
  /// from a mobile banking service.
  final bool bankLike;

  /// Money came in.
  bool get isIncome => switch (kind) {
    SmsKind.cashIn || SmsKind.received => true,
    _ => false,
  };
}

/// A figure: after `Tk`, `BDT`, `৳`, `টাকা` or a label like `Amount:` and
/// `Fee:`, or before a currency word. The label stays out of the figure, and
/// `recharge` is not `charge` (nothing may sit before the label).
final _money = RegExp(
  r'(?:(?<![A-Za-z])(?:tk|bdt|taka|টাকা|amount|amt|fees?|charges?|balance|bal)'
  r'\.?\s*:?\s*|৳\s*)(\d[\d,]*(?:\.\d{1,2})?)'
  r'|(\d[\d,]*(?:\.\d{1,2})?)\s*(?:tk|bdt|taka|৳|টাকা)(?![A-Za-z])',
  caseSensitive: false,
);

final _trxId = RegExp(
  r'(trx\s*id|txn\s*id|trnx\s*id|transaction\s*id|ref(?:erence)?(?:\s*no)?)'
  r'\s*[:#]?\s*([A-Za-z0-9]{6,})',
  caseSensitive: false,
);

final _accountDigits = RegExp(
  r'[xX*•]{2,}\s*(\d{3,4})(?!\d)'
  r'|\b(?:a/?c|acc(?:ount)?|card)\s*(?:no\.?|number|#)?\s*'
  r'(?:ending(?:\s+with|\s+in)?)?\s*[:#]?\s*[xX*•.\-]*(\d{4,})',
  caseSensitive: false,
);

final _bankWords = RegExp(
  r'\b(?:atm|a/c|pos|card|bank|visa|mastercard)\b',
  caseSensitive: false,
);

/// Bangla digits to the digits the rest of the reading expects.
String _asciiDigits(String text) => text.replaceAllMapped(
  RegExp('[০-৯]'),
  (m) => '${m[0]!.codeUnitAt(0) - 0x09E6}',
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
SmsEntry? parseSms(String pasted) {
  final text = _asciiDigits(pasted);
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
    // The words just before the figure, and the label it carries itself
    // ("Fee: 5.00").
    final before = '${text.substring(from, match.start)} ${match.group(0)!}'
        .toLowerCase();
    previousEnd = match.end;
    if (poisha == null) continue;

    // "charge" alone: "recharge" is not a fee.
    if (RegExp(r'\b(fees?|charges?)\b|ফি|চার্জ').hasMatch(before)) {
      fee = poisha;
    } else if (before.contains('bal') ||
        before.contains('limit') ||
        before.contains('outstanding') ||
        before.contains('ব্যালেন্স')) {
      balance ??= poisha;
    } else if (before.contains('vat')) {
      continue;
    } else {
      amount ??= poisha;
    }
  }
  if (amount == null || amount <= 0) return null;

  final phone = _phone.firstMatch(text)?.group(1);
  final trx = _trxId.firstMatch(text);
  final provider = _providerOf(lower);
  final digits = _accountDigitsOf(text);
  final idStyle = trx?.group(1)?.toLowerCase().replaceAll(RegExp(r'\s'), '');
  return SmsEntry(
    kind: kind,
    amount: amount,
    fee: fee,
    balance: balance,
    trxId: trx?.group(2),
    counterparty: phone ?? _shop.firstMatch(text)?.group(1)?.trim(),
    provider: provider,
    date: _dateOf(text),
    accountHint: digits,
    bankLike: digits != null || _bankWords.hasMatch(lower),
    source:
        provider ??
        (digits != null
            ? 'ac$digits'
            : (idStyle != null && !idStyle.startsWith('ref')
                  ? 'id-$idStyle'
                  : null)),
  );
}

/// The last four digits of the account or card a message names.
String? _accountDigitsOf(String text) {
  final match = _accountDigits.firstMatch(text);
  final digits = match?.group(1) ?? match?.group(2);
  if (digits == null) return null;
  return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
}

bool _has(String t, String pattern) => RegExp(pattern).hasMatch(t);

SmsKind? _kindOf(String t) {
  if (_has(t, r'cash[\s-]?out|\bwithdraw|ক্যাশ\s*আউট|উত্তোলন')) {
    return SmsKind.cashOut;
  }
  if (_has(t, r'\bcash[\s-]?in\b|ক্যাশ\s*ইন')) return SmsKind.cashIn;
  if (_has(
    t,
    r'refund|cash\s?back|\b(received|credited|credit(?!\s*card)|deposited|'
    r'deposit|add money|salary)\b|পেয়েছেন|প্রাপ্ত|জমা|ক্রেডিট|রিফান্ড|'
    r'ক্যাশব্যাক',
  )) {
    return SmsKind.received;
  }
  if (_has(t, r'recharge|top[\s-]?up|রিচার্জ')) return SmsKind.recharge;
  if (_has(t, r'\bbill|বিল(?!ম্ব)')) return SmsKind.bill;
  if (_has(
    t,
    r'send[\s-]?money|\b(sent|transferred|transfer|b2b)\b|সেন্ড\s*মানি|'
    r'পাঠিয়েছেন|পাঠানো|ট্রান্সফার',
  )) {
    return SmsKind.sent;
  }
  if (_has(
    t,
    r'\b(payment|paid|pay|purchase|purchased|spent|pos|bought)\b|পেমেন্ট|'
    r'পরিশোধ|কেনাকাটা|কিনেছেন',
  )) {
    return SmsKind.payment;
  }
  if (_has(
    t,
    r'\b(debited|debit|deducted|charged)\b|কাটা\s*হয়েছে|কর্তন|ডেবিট',
  )) {
    return SmsKind.debited;
  }
  return null;
}

String? _providerOf(String t) {
  for (final name in const ['bkash', 'nagad', 'rocket', 'upay']) {
    if (t.contains(name)) return name;
  }
  const bangla = {
    'বিকাশ': 'bkash',
    'নগদ': 'nagad',
    'রকেট': 'rocket',
    'উপায়': 'upay',
  };
  for (final entry in bangla.entries) {
    if (t.contains(entry.key)) return entry.value;
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
