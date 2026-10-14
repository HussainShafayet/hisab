import 'package:hishab/core/l10n/bn_strings.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/categories/data/parent_suggestion.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What one typed line like `rickshaw 50`, `bazar 450 bkash` or `+salary 30k`
/// says about a new transaction. Anything the line does not say is null.
class QuickEntry {
  const QuickEntry({
    required this.type,
    required this.note,
    this.amount,
    this.account,
    this.category,
  });

  /// Only an expense or an income; a transfer is never typed in one line.
  final TransactionType type;

  /// In poisha.
  final int? amount;

  /// The words left over once the amount and the account are taken out.
  final String note;
  final Account? account;
  final Category? category;

  /// Whether the line told us nothing at all.
  bool get isEmpty =>
      amount == null && account == null && category == null && note.isEmpty;
}

const _bengaliDigits = '০১২৩৪৫৬৭৮৯';

/// Words that make the line an income when no `+` starts it.
const _incomeWords = {
  'salary',
  'bonus',
  'income',
  'received',
  'pelam',
  'pailam',
  'profit',
  'refund',
  'cashback',
  'বেতন',
  'পেলাম',
  'পাইলাম',
};

/// Words next to a number that stand for taka, thousands or lakhs.
const _unitMultipliers = {
  'k': 1000,
  'hajar': 1000,
  'hazar': 1000,
  'হাজার': 1000,
  'lakh': 100000,
  'lac': 100000,
  'লাখ': 100000,
  'tk': 1,
  'taka': 1,
  'টাকা': 1,
  '/-': 1,
};

final _numberToken = RegExp(
  r'^(\d+(?:\.\d{1,2})?)(k|tk|taka|টাকা|/-|lakh|lac|লাখ|হাজার)?$',
);

String _asciiDigits(String text) {
  final out = StringBuffer();
  for (final unit in text.split('')) {
    final index = _bengaliDigits.indexOf(unit);
    out.write(index >= 0 ? '$index' : unit);
  }
  return out.toString();
}

String _key(String text) => text.trim().toLowerCase();

List<String> _words(String text) =>
    _key(text)
        .split(RegExp(r'[^a-z0-9ঀ-৿]+'))
        .where((w) => w.length >= 3)
        .toList();

String _capitalised(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Reads one typed line. The amount is the last number in it (`2k` is 2,000,
/// `1.5 hajar` is 1,500, Bengali digits work), a word that is the name of an
/// account picks that account, and the words that are left are matched with
/// the categories: first by name, then by the everyday words of life in
/// Bangladesh ("ilish" is Fish).
QuickEntry parseQuickEntry(String text, AddTransactionOptions options) {
  final raw = _asciiDigits(text)
      .replaceAll('৳', ' ')
      .replaceAllMapped(RegExp(r'(\d),(?=\d)'), (m) => m[1]!);
  final shown = raw.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  var income = false;
  if (shown.isNotEmpty && shown.first.startsWith('+')) {
    income = true;
    shown[0] = shown.first.substring(1);
    if (shown.first.isEmpty) shown.removeAt(0);
  }
  final lower = [for (final t in shown) _key(t)];
  final taken = <int>{};

  // The amount: the last number, with a unit before or after it.
  int? amount;
  for (var i = lower.length - 1; i >= 0 && amount == null; i--) {
    final match = _numberToken.firstMatch(lower[i]);
    if (match == null) continue;
    var multiplier = _unitMultipliers[match.group(2)] ?? 1;
    final base = parseTakaToPoisha(match.group(1)!);
    if (base == null) continue;
    taken.add(i);
    final next = i + 1 < lower.length ? lower[i + 1] : null;
    if (match.group(2) == null && next != null) {
      final unit = _unitMultipliers[next];
      if (unit != null) {
        multiplier = unit;
        taken.add(i + 1);
      }
    }
    final value = base * multiplier;
    if (value > 0) amount = value;
  }

  if (lower.any(_incomeWords.contains)) income = true;
  final type = income ? TransactionType.income : TransactionType.expense;

  // The account: a word that is a word of an account's name.
  Account? account;
  for (final candidate in options.accounts) {
    if (candidate.isArchived) continue;
    final names = {
      ..._words(candidate.name),
      ..._words(bnStrings[candidate.name] ?? ''),
    };
    final hit = lower.indexed.where((e) {
      if (taken.contains(e.$1) || e.$2.length < 3) return false;
      return names.any(
        (n) => n == e.$2 || (e.$2.length >= 4 && n.startsWith(e.$2)),
      );
    });
    if (hit.isNotEmpty) {
      account = candidate;
      taken.add(hit.first.$1);
      break;
    }
  }

  final left = [
    for (var i = 0; i < shown.length; i++)
      if (!taken.contains(i)) shown[i],
  ];
  final note = _capitalised(left.join(' '));
  final leftLower = [for (final t in left) _key(t)];

  final category = leftLower.isEmpty
      ? null
      : _matchCategory(
          whole: leftLower.join(' '),
          tokens: leftLower,
          type: income ? CategoryType.income : CategoryType.expense,
          options: options,
        );

  return QuickEntry(
    type: type,
    amount: amount,
    note: note,
    account: account,
    category: category,
  );
}

Category? _matchCategory({
  required String whole,
  required List<String> tokens,
  required CategoryType type,
  required AddTransactionOptions options,
}) {
  final pool = options
      .categoriesFor(
        type == CategoryType.income
            ? TransactionType.income
            : TransactionType.expense,
      )
      .where((c) => !c.isArchived)
      .toList();
  String bangla(Category c) => _key(bnStrings[c.name] ?? '');

  bool named(Category c, String text) =>
      _key(c.name) == text || bangla(c) == text;

  for (final c in pool) {
    if (named(c, whole)) return c;
  }
  for (final token in tokens) {
    for (final c in pool) {
      if (token.length >= 3 && named(c, token)) return c;
    }
  }

  // A word that is a word of a category's name ("rickshaw" is in "Bus &
  // rickshaw") is the most exact hint, then the everyday words table.
  for (final token in tokens) {
    if (token.length < 4) continue;
    final inName = pool
        .where(
          (c) =>
              _words(c.name).contains(token) ||
              _words(bangla(c)).contains(token),
        )
        .toList();
    if (inName.isNotEmpty) {
      inName.sort((a, b) => a.name.length.compareTo(b.name.length));
      return inName.first;
    }
  }

  final all = [...options.expenseCategories, ...options.incomeCategories];
  final suggested = suggestParent(name: whole, type: type, all: all);
  if (suggested != null) return suggested;
  for (final token in tokens) {
    if (token.length < 4) continue;
    final byWord = suggestParent(name: token, type: type, all: all);
    if (byWord != null) return byWord;
  }
  return null;
}
