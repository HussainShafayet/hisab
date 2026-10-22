import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/sheet_amount.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:intl/intl.dart';

/// The category used for an expense row with no category.
const defaultExpenseCategoryName = 'Other';

/// The category used for an income row with no category.
const defaultIncomeCategoryName = 'Other income';

const maxImportNoteLength = 500;

/// A name for comparing: trimmed, one space between words, lower case. "bKash"
/// and " bkash " are the same account.
String normalizeName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class ExistingAccount {
  const ExistingAccount({
    required this.id,
    required this.name,
    this.includeInTotal = true,
  });

  final int id;
  final String name;

  /// Whether its balance counts in the total balance.
  final bool includeInTotal;
}

class ExistingCategory {
  const ExistingCategory({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.isArchived = false,
  });

  final int id;
  final String name;
  final CategoryType type;
  final int? parentId;
  final bool isArchived;
}

/// "Food > Groceries" as `['Food', 'Groceries']`. Both `>` and `›` split.
List<String> splitCategoryPath(String raw) => [
  for (final part in raw.split(RegExp(r'[>›]')))
    if (part.trim().isNotEmpty) part.trim(),
];

/// Finds the categories a CSV row names among the ones that exist. Names are
/// compared without regard to case or extra spaces.
class CategoryResolver {
  CategoryResolver(Iterable<ExistingCategory> categories)
    : _all = [...categories];

  final List<ExistingCategory> _all;

  /// Makes a category created during the import known, so a later row finds it.
  void add(ExistingCategory category) => _all.add(category);

  /// An active category is preferred over an archived one of the same name.
  int? _first(Iterable<ExistingCategory> matches) {
    ExistingCategory? archived;
    for (final category in matches) {
      if (!category.isArchived) return category.id;
      archived ??= category;
    }
    return archived?.id;
  }

  int? findTopLevel(String name, CategoryType type) => _first(
    _all.where(
      (c) =>
          c.parentId == null &&
          c.type == type &&
          normalizeName(c.name) == normalizeName(name),
    ),
  );

  int? findChild(int parentId, String name) => _first(
    _all.where(
      (c) =>
          c.parentId == parentId &&
          normalizeName(c.name) == normalizeName(name),
    ),
  );

  /// A top-level category with that name, else a sub-category with it.
  int? findAny(String name, CategoryType type) =>
      findTopLevel(name, type) ??
      _first(
        _all.where(
          (c) =>
              c.parentId != null &&
              c.type == type &&
              normalizeName(c.name) == normalizeName(name),
        ),
      );

  /// The id for a category path of one or more names (`Food`, or
  /// `Food > Restaurant > Dinner`), or null if it does not exist (yet). A
  /// single name also finds a sub-category of that name.
  int? find(List<String> path, CategoryType type) {
    if (path.length == 1) return findAny(path.first, type);
    var current = findTopLevel(path.first, type);
    for (final name in path.skip(1)) {
      if (current == null) return null;
      current = findChild(current, name);
    }
    return current;
  }
}

/// The key of a category named in a file, to match it with one of the app's.
String categoryKey(CategoryType type, List<String> path) =>
    '${type.name}|${path.map(normalizeName).join('>')}';

/// An existing category that the new category [name] probably means: of the
/// same [type], with a name that holds the new one or is held by it
/// ("Transportation" and "Transport"), the closest in length first. Null when
/// nothing looks alike. This is only a suggestion for the person to accept.
ExistingCategory? similarCategory(
  String name,
  CategoryType type,
  Iterable<ExistingCategory> existing,
) {
  // Letters only, and the plural taken off: "Utilities" is "utility", "Foods"
  // is "food".
  String squash(String text) {
    final word = normalizeName(text)
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    if (word.length > 4 && word.endsWith('ies')) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  final wanted = squash(name);
  if (wanted.length < 4) return null;

  ExistingCategory? best;
  var bestGap = 1 << 30;
  for (final category in existing) {
    if (category.type != type || category.isArchived) continue;
    final other = squash(category.name);
    if (other.length < 4) continue;
    if (!other.contains(wanted) && !wanted.contains(other)) continue;
    final gap = (other.length - wanted.length).abs();
    if (gap < bestGap) {
      best = category;
      bestGap = gap;
    }
  }
  return best;
}

/// A guess at the kind of account from its name, for accounts that are created
/// by an import: bKash and Nagad are mobile banking, anything with "bank" is a
/// bank, cards are cards (a credit card if it says so), everything else is
/// cash.
AccountType guessAccountType(String name) {
  final lower = name.toLowerCase();
  bool has(List<String> words) => words.any(lower.contains);
  if (has(['bkash', 'nagad', 'rocket', 'upay', 'mobile'])) {
    return AccountType.mobileBanking;
  }
  if (has(['credit'])) return AccountType.creditCard;
  if (has(['card', 'visa', 'mastercard'])) return AccountType.card;
  if (has(['bank', 'savings', 'dps', 'fdr', 'current'])) {
    return AccountType.bank;
  }
  return AccountType.cash;
}

/// What makes two transactions the same one for the duplicate check: the day,
/// type, amount, accounts and note. The category is left out because it may
/// have been changed after the first import, and so is the time of day,
/// because a spreadsheet usually has none.
String duplicateKey({
  required DateTime date,
  required TransactionType type,
  required int amount,
  required int accountId,
  required String note,
  int? toAccountId,
}) {
  final day =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return '$day|${type.name}|$amount|$accountId|${toAccountId ?? ''}|'
      '${normalizeName(note)}';
}

/// What the app already holds, for matching the rows of a file against.
class ImportContext {
  const ImportContext({
    required this.accounts,
    required this.categories,
    required this.existingKeyCounts,
  });

  final List<ExistingAccount> accounts;
  final List<ExistingCategory> categories;

  /// How many existing transactions have each [duplicateKey].
  final Map<String, int> existingKeyCounts;
}

enum RowStatus {
  /// Will be imported.
  ok,

  /// The app already has this transaction: it is skipped.
  duplicate,

  /// Cannot be read: it is skipped, and [PlannedRow.error] says why.
  error,
}

/// A row of the file, read.
class ParsedRow {
  const ParsedRow({
    required this.date,
    required this.type,
    required this.amount,
    required this.accountName,
    required this.note,
    this.toAccountName,
    this.categoryPath = const [],
  });

  final DateTime date;
  final TransactionType type;

  /// In poisha, above zero.
  final int amount;
  final String accountName;
  final String? toAccountName;

  /// From the top-level category down, empty for a transfer.
  final List<String> categoryPath;
  final String note;
}

class PlannedRow {
  const PlannedRow({
    required this.rowNumber,
    required this.status,
    this.parsed,
    this.error,
    this.warning,
  });

  /// 1 for the first data row (the header row is not counted).
  final int rowNumber;
  final RowStatus status;

  /// Set unless the row is an error.
  final ParsedRow? parsed;
  final String? error;

  /// Something to look at in a row that is imported all the same, such as a
  /// date that does not fit the rows around it.
  final String? warning;

  PlannedRow withWarning(String warning) => PlannedRow(
    rowNumber: rowNumber,
    status: status,
    parsed: parsed,
    error: error,
    warning: warning,
  );
}

/// A category the import will create, with its parent when it has one.
class CategoryToCreate {
  const CategoryToCreate({
    required this.path,
    required this.type,
    this.suggestion,
  });

  /// From the top-level category down: one name, or several for a
  /// sub-category.
  final List<String> path;
  final CategoryType type;

  /// A category the app has that this one may be meant as, if one looks alike.
  final ExistingCategory? suggestion;

  String get label => path.join(' > ');

  /// What the file's rows of this category are matched by.
  String get key => categoryKey(type, path);

  CategoryToCreate withSuggestion(ExistingCategory? suggestion) =>
      CategoryToCreate(path: path, type: type, suggestion: suggestion);
}

/// What an import does to the balance of one account.
class AccountChange {
  const AccountChange({
    required this.name,
    required this.change,
    required this.isNew,
    required this.includeInTotal,
  });

  final String name;

  /// In poisha, negative when the account ends with less.
  final int change;

  /// The account does not exist yet: it starts from nothing.
  final bool isNew;

  /// Whether the account counts in the total balance.
  final bool includeInTotal;
}

class _Change {
  _Change(this.name, {required this.isNew, required this.includeInTotal});

  final String name;
  final bool isNew;
  final bool includeInTotal;
  int delta = 0;
}

/// What an import will do, worked out before anything is changed so it can be
/// shown in a preview.
class ImportPlan {
  const ImportPlan({
    required this.rows,
    required this.newAccounts,
    required this.newCategories,
    this.accountChanges = const [],
    this.categoryMap = const {},
  });

  final List<PlannedRow> rows;

  /// How the rows to import change the balance of each account they touch.
  final List<AccountChange> accountChanges;

  /// The categories of the file that were matched with one of the app's by
  /// the person, by [categoryKey]. The import uses them in place of making
  /// a new category.
  final Map<String, int> categoryMap;

  /// Accounts in the file that the app does not have yet.
  final List<String> newAccounts;

  /// Categories in the rows to import that the app does not have yet.
  final List<CategoryToCreate> newCategories;

  List<PlannedRow> get toImport =>
      rows.where((r) => r.status == RowStatus.ok).toList();

  int get importCount => toImport.length;
  int get duplicateCount =>
      rows.where((r) => r.status == RowStatus.duplicate).length;
  int get errorCount => rows.where((r) => r.status == RowStatus.error).length;

  /// Rows to import that have something to look at.
  int get warningCount => rows.where((r) => r.warning != null).length;
}

/// A date this far from the rows around it is looked at.
const _oddDateDays = 45;

/// Marks the rows to import whose date is far from the rows around them: the
/// day and month the wrong way round, a wrong year. The rows near it (two
/// before and two after) have to agree among themselves, so a file that jumps
/// between dates is not marked.
List<PlannedRow> markOddDates(List<PlannedRow> rows) {
  final dated = [
    for (var i = 0; i < rows.length; i++)
      if (rows[i].status == RowStatus.ok) i,
  ];
  final result = [...rows];
  final format = DateFormat('d MMM yyyy');

  for (var k = 0; k < dated.length; k++) {
    final around = <DateTime>[
      for (var j = k - 2; j <= k + 2; j++)
        if (j != k && j >= 0 && j < dated.length) rows[dated[j]].parsed!.date,
    ]..sort();
    if (around.length < 2) continue;
    if (around.last.difference(around.first).inDays > _oddDateDays) continue;

    final middle = around[around.length ~/ 2];
    final date = rows[dated[k]].parsed!.date;
    if (date.difference(middle).inDays.abs() <= _oddDateDays) continue;

    final swapped = date.day <= 12
        ? DateTime(date.year, date.day, date.month, date.hour, date.minute)
        : null;
    final fits =
        swapped != null &&
        swapped.month == date.day &&
        swapped.difference(middle).inDays.abs() <= _oddDateDays;
    result[dated[k]] = rows[dated[k]].withWarning(
      fits
          ? tr(
              'This date may have the day and month the wrong way round: {date}?',
              {'date': format.format(swapped)},
            )
          : tr(
              'This date is far from the rows around it, which are near {date}.',
              {'date': format.format(middle)},
            ),
    );
  }
  return result;
}

/// What the amount cells of a row say: the amount in poisha with its sign and,
/// when income and expense have a column each, the type; or why the row cannot
/// be read.
({int signed, TransactionType? type, String? error}) _readAmount(
  String Function(ImportField field) cell,
  ImportMapping mapping,
) {
  ({int signed, TransactionType? type, String? error}) fail(String error) =>
      (signed: 0, type: null, error: error);

  if (mapping.typeSource == TypeSource.twoColumns) {
    final incomeText = cell(ImportField.incomeAmount);
    final expenseText = cell(ImportField.expenseAmount);
    if (incomeText.isEmpty && expenseText.isEmpty) {
      return fail(tr('The amount is empty.'));
    }
    final income = incomeText.isEmpty ? 0 : parseSheetAmount(incomeText);
    final expense = expenseText.isEmpty ? 0 : parseSheetAmount(expenseText);
    if (income == null) {
      return fail(tr('"{text}" is not an amount.', {'text': incomeText}));
    }
    if (expense == null) {
      return fail(tr('"{text}" is not an amount.', {'text': expenseText}));
    }
    if (income != 0 && expense != 0) {
      return fail(tr('Both the income and the expense column have an amount.'));
    }
    if (income == 0 && expense == 0) return fail(tr('The amount is zero.'));
    return income != 0
        ? (signed: income.abs(), type: TransactionType.income, error: null)
        : (signed: expense.abs(), type: TransactionType.expense, error: null);
  }

  final amountText = cell(ImportField.amount);
  if (amountText.isEmpty) return fail(tr('The amount is empty.'));
  final signed = parseSheetAmount(amountText);
  if (signed == null) {
    return fail(tr('"{text}" is not an amount.', {'text': amountText}));
  }
  if (signed == 0) return fail(tr('The amount is zero.'));
  return (signed: signed, type: null, error: null);
}

/// Reads every row of [table] with [mapping] and decides what to do with it:
/// import it, skip it as a duplicate, or skip it as unreadable. Nothing is
/// changed; the result is for the preview and for the import itself.
ImportPlan buildImportPlan({
  required CsvTable table,
  required ImportMapping mapping,
  required ImportContext context,
  Map<String, int> categoryMap = const {},
}) {
  final accounts = {for (final a in context.accounts) normalizeName(a.name): a};
  final resolver = CategoryResolver(context.categories);
  final remaining = Map<String, int>.of(context.existingKeyCounts);
  final newAccounts = <String, String>{};
  final newCategories = <String, CategoryToCreate>{};
  final changes = <String, _Change>{};
  final rows = <PlannedRow>[];
  final categoryIds = {for (final c in context.categories) c.id};

  void move(String accountName, int delta) {
    final key = normalizeName(accountName);
    final account = accounts[key];
    changes
            .putIfAbsent(
              key,
              () => _Change(
                account?.name ?? accountName,
                isNew: account == null,
                includeInTotal: account?.includeInTotal ?? true,
              ),
            )
            .delta +=
        delta;
  }

  final defaultAccount = context.accounts
      .where((a) => a.id == mapping.defaultAccountId)
      .firstOrNull;

  for (var i = 0; i < table.rows.length; i++) {
    final rowNumber = i + 1;
    String cell(ImportField field) {
      final column = mapping.columnOf(field);
      return column == null ? '' : table.cell(i, column);
    }

    PlannedRow fail(String message) => PlannedRow(
      rowNumber: rowNumber,
      status: RowStatus.error,
      error: message,
    );

    final dateText = cell(ImportField.date);
    if (dateText.isEmpty) {
      rows.add(fail(tr('The date is empty.')));
      continue;
    }
    final date = parseSheetDate(dateText, mapping.dateFormat);
    if (date == null) {
      rows.add(
        fail(
          tr('"{text}" is not a {format} date.', {
            'text': dateText,
            'format': mapping.dateFormat.label,
          }),
        ),
      );
      continue;
    }

    final read = _readAmount(cell, mapping);
    if (read.error != null) {
      rows.add(fail(read.error!));
      continue;
    }
    final signed = read.signed;

    final TransactionType type;
    switch (mapping.typeSource) {
      case TypeSource.column:
        final typeText = cell(ImportField.type);
        final parsedType = parseTypeText(typeText);
        if (parsedType == null) {
          rows.add(
            fail(
              typeText.isEmpty
                  ? tr('The type is empty.')
                  : tr('"{text}" is not income, expense or transfer.', {
                      'text': typeText,
                    }),
            ),
          );
          continue;
        }
        type = parsedType;
      case TypeSource.amountSign:
        type = signed < 0 ? TransactionType.expense : TransactionType.income;
      case TypeSource.allExpense:
        type = TransactionType.expense;
      case TypeSource.allIncome:
        type = TransactionType.income;
      case TypeSource.twoColumns:
        type = read.type!;
    }
    final amount = signed.abs();

    final accountCell = cell(ImportField.account);
    final accountName = accountCell.isNotEmpty
        ? accountCell
        : (defaultAccount?.name ?? '');
    if (accountName.isEmpty) {
      rows.add(
        fail(tr('There is no account. Choose one for rows without it.')),
      );
      continue;
    }

    String? toAccountName;
    var categoryPath = <String>[];
    if (type == TransactionType.transfer) {
      toAccountName = cell(ImportField.toAccount);
      if (toAccountName.isEmpty) {
        rows.add(fail(tr('A transfer needs a "to account".')));
        continue;
      }
      if (normalizeName(toAccountName) == normalizeName(accountName)) {
        rows.add(fail(tr('A transfer needs two different accounts.')));
        continue;
      }
    } else {
      final categoryCell = cell(ImportField.category);
      categoryPath = splitCategoryPath(categoryCell);
      if (categoryPath.length > maxCategoryDepth) {
        rows.add(
          fail(
            tr('"{text}" has more than {levels} levels.', {
              'text': categoryCell,
              'levels': maxCategoryDepth,
            }),
          ),
        );
        continue;
      }
      if (categoryPath.isEmpty) {
        categoryPath = [
          type == TransactionType.income
              ? defaultIncomeCategoryName
              : defaultExpenseCategoryName,
        ];
      }
    }

    var note = cell(ImportField.note);
    if (note.length > maxImportNoteLength) {
      note = note.substring(0, maxImportNoteLength);
    }

    // A duplicate needs accounts the app already has; a new account has no
    // transactions yet.
    final account = accounts[normalizeName(accountName)];
    final toAccount = toAccountName == null
        ? null
        : accounts[normalizeName(toAccountName)];
    var isDuplicate = false;
    if (account != null && (toAccountName == null || toAccount != null)) {
      final key = duplicateKey(
        date: date,
        type: type,
        amount: amount,
        accountId: account.id,
        toAccountId: toAccount?.id,
        note: note,
      );
      if ((remaining[key] ?? 0) > 0) {
        remaining[key] = remaining[key]! - 1;
        isDuplicate = true;
      }
    }

    final parsed = ParsedRow(
      date: date,
      type: type,
      amount: amount,
      accountName: accountName,
      toAccountName: toAccountName,
      categoryPath: categoryPath,
      note: note,
    );
    if (isDuplicate) {
      rows.add(
        PlannedRow(
          rowNumber: rowNumber,
          status: RowStatus.duplicate,
          parsed: parsed,
        ),
      );
      continue;
    }

    // Only rows that will be imported make accounts and categories.
    if (account == null) {
      newAccounts.putIfAbsent(normalizeName(accountName), () => accountName);
    }
    if (toAccountName != null && toAccount == null) {
      newAccounts.putIfAbsent(
        normalizeName(toAccountName),
        () => toAccountName!,
      );
    }
    if (type != TransactionType.transfer) {
      final categoryType = type.categoryType!;
      final key = categoryKey(categoryType, categoryPath);
      final mapped = categoryMap[key];
      final isMapped = mapped != null && categoryIds.contains(mapped);
      if (!isMapped && resolver.find(categoryPath, categoryType) == null) {
        newCategories.putIfAbsent(
          key,
          () => CategoryToCreate(path: categoryPath, type: categoryType),
        );
      }
    }

    switch (type) {
      case TransactionType.income:
        move(accountName, amount);
      case TransactionType.expense:
        move(accountName, -amount);
      case TransactionType.transfer:
        move(accountName, -amount);
        move(toAccountName!, amount);
    }
    rows.add(
      PlannedRow(rowNumber: rowNumber, status: RowStatus.ok, parsed: parsed),
    );
  }

  return ImportPlan(
    rows: markOddDates(rows),
    newAccounts: newAccounts.values.toList(),
    newCategories: [
      for (final category in newCategories.values)
        category.path.length == 1
            ? category.withSuggestion(
                similarCategory(
                  category.path.first,
                  category.type,
                  context.categories,
                ),
              )
            : category,
    ],
    accountChanges: [
      for (final change in changes.values)
        AccountChange(
          name: change.name,
          change: change.delta,
          isNew: change.isNew,
          includeInTotal: change.includeInTotal,
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    categoryMap: categoryMap,
  );
}
