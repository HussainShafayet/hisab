import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/sheet_amount.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

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
  const ExistingAccount({required this.id, required this.name});

  final int id;
  final String name;
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

/// A guess at the kind of account from its name, for accounts that are created
/// by an import: bKash and Nagad are mobile banking, anything with "bank" is a
/// bank, cards are cards, everything else is cash.
AccountType guessAccountType(String name) {
  final lower = name.toLowerCase();
  bool has(List<String> words) => words.any(lower.contains);
  if (has(['bkash', 'nagad', 'rocket', 'upay', 'mobile'])) {
    return AccountType.mobileBanking;
  }
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
  });

  /// 1 for the first data row (the header row is not counted).
  final int rowNumber;
  final RowStatus status;

  /// Set unless the row is an error.
  final ParsedRow? parsed;
  final String? error;
}

/// A category the import will create, with its parent when it has one.
class CategoryToCreate {
  const CategoryToCreate({required this.path, required this.type});

  /// From the top-level category down: one name, or several for a
  /// sub-category.
  final List<String> path;
  final CategoryType type;

  String get label => path.join(' > ');
}

/// What an import will do, worked out before anything is changed so it can be
/// shown in a preview.
class ImportPlan {
  const ImportPlan({
    required this.rows,
    required this.newAccounts,
    required this.newCategories,
  });

  final List<PlannedRow> rows;

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
}

/// Reads every row of [table] with [mapping] and decides what to do with it:
/// import it, skip it as a duplicate, or skip it as unreadable. Nothing is
/// changed; the result is for the preview and for the import itself.
ImportPlan buildImportPlan({
  required CsvTable table,
  required ImportMapping mapping,
  required ImportContext context,
}) {
  final accounts = {for (final a in context.accounts) normalizeName(a.name): a};
  final resolver = CategoryResolver(context.categories);
  final remaining = Map<String, int>.of(context.existingKeyCounts);
  final newAccounts = <String, String>{};
  final newCategories = <String, CategoryToCreate>{};
  final rows = <PlannedRow>[];

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
      rows.add(fail('The date is empty.'));
      continue;
    }
    final date = parseSheetDate(dateText, mapping.dateFormat);
    if (date == null) {
      rows.add(fail('"$dateText" is not a ${mapping.dateFormat.label} date.'));
      continue;
    }

    final amountText = cell(ImportField.amount);
    if (amountText.isEmpty) {
      rows.add(fail('The amount is empty.'));
      continue;
    }
    final signed = parseSheetAmount(amountText);
    if (signed == null) {
      rows.add(fail('"$amountText" is not an amount.'));
      continue;
    }
    if (signed == 0) {
      rows.add(fail('The amount is zero.'));
      continue;
    }

    final TransactionType type;
    switch (mapping.typeSource) {
      case TypeSource.column:
        final typeText = cell(ImportField.type);
        final parsedType = parseTypeText(typeText);
        if (parsedType == null) {
          rows.add(
            fail(
              typeText.isEmpty
                  ? 'The type is empty.'
                  : '"$typeText" is not income, expense or transfer.',
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
    }
    final amount = signed.abs();

    final accountCell = cell(ImportField.account);
    final accountName = accountCell.isNotEmpty
        ? accountCell
        : (defaultAccount?.name ?? '');
    if (accountName.isEmpty) {
      rows.add(fail('There is no account. Choose one for rows without it.'));
      continue;
    }

    String? toAccountName;
    var categoryPath = <String>[];
    if (type == TransactionType.transfer) {
      toAccountName = cell(ImportField.toAccount);
      if (toAccountName.isEmpty) {
        rows.add(fail('A transfer needs a "to account".'));
        continue;
      }
      if (normalizeName(toAccountName) == normalizeName(accountName)) {
        rows.add(fail('A transfer needs two different accounts.'));
        continue;
      }
    } else {
      final categoryCell = cell(ImportField.category);
      categoryPath = splitCategoryPath(categoryCell);
      if (categoryPath.length > maxCategoryDepth) {
        rows.add(
          fail('"$categoryCell" has more than $maxCategoryDepth levels.'),
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
      if (resolver.find(categoryPath, categoryType) == null) {
        final key =
            '${categoryType.name}|${categoryPath.map(normalizeName).join('>')}';
        newCategories.putIfAbsent(
          key,
          () => CategoryToCreate(path: categoryPath, type: categoryType),
        );
      }
    }
    rows.add(
      PlannedRow(rowNumber: rowNumber, status: RowStatus.ok, parsed: parsed),
    );
  }

  return ImportPlan(
    rows: rows,
    newAccounts: newAccounts.values.toList(),
    newCategories: newCategories.values.toList(),
  );
}
