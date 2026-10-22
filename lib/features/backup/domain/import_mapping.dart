import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/sheet_amount.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The things a CSV row can say about a transaction.
enum ImportField {
  date('Date', isRequired: true),
  amount('Amount', isRequired: true),
  incomeAmount('Income amount'),
  expenseAmount('Expense amount'),
  type('Type (income, expense, transfer)'),
  category('Category'),
  account('Account'),
  toAccount('To account (transfers)'),
  note('Note or description');

  const ImportField(this._label, {this.isRequired = false});

  final String _label;

  /// What the field is called for the user.
  String get label => tr(_label);

  final bool isRequired;

  /// Whether the field is asked for when the type comes from [source]: with a
  /// column each for income and expense, those two stand in for the one amount.
  bool isAskedFor(TypeSource source) => switch (this) {
    ImportField.amount => source != TypeSource.twoColumns,
    ImportField.incomeAmount ||
    ImportField.expenseAmount => source == TypeSource.twoColumns,
    _ => true,
  };
}

/// Where the type (income, expense, transfer) of each row comes from.
enum TypeSource {
  /// A column holds the type.
  column('A column of my file'),

  /// A negative amount is an expense and a positive one is income.
  amountSign('The sign of the amount'),

  /// Every row is an expense.
  allExpense('All rows are expenses'),

  /// Every row is income.
  allIncome('All rows are income'),

  /// One column holds the income amounts and another the expense amounts; a
  /// row fills one of them.
  twoColumns('Separate income and expense columns');

  const TypeSource(this._label);

  final String _label;

  /// What the choice is called for the user.
  String get label => tr(_label);
}

/// How the columns of a CSV file map to the fields of a transaction.
class ImportMapping {
  const ImportMapping({
    required this.columns,
    required this.dateFormat,
    required this.typeSource,
    this.defaultAccountId,
  });

  /// The 0 based column of the file for each mapped field. A field that is
  /// not in the map is not in the file.
  final Map<ImportField, int> columns;

  final SheetDateFormat dateFormat;
  final TypeSource typeSource;

  /// The account for rows with no account of their own.
  final int? defaultAccountId;

  int? columnOf(ImportField field) => columns[field];

  Map<String, Object?> toJson() => {
    'columns': {for (final e in columns.entries) e.key.name: e.value},
    'dateFormat': dateFormat.name,
    'typeSource': typeSource.name,
    'defaultAccountId': defaultAccountId,
  };

  /// A mapping saved with [toJson] for a file with [columnCount] columns, or
  /// null when the saved one is damaged or points past the columns of the file.
  static ImportMapping? fromJson(Object? json, {required int columnCount}) {
    if (json is! Map) return null;
    final raw = json['columns'];
    if (raw is! Map) return null;

    final columns = <ImportField, int>{};
    for (final entry in raw.entries) {
      final field = ImportField.values
          .where((f) => f.name == entry.key)
          .firstOrNull;
      final column = entry.value;
      if (field == null || column is! int) return null;
      if (column < 0 || column >= columnCount) return null;
      columns[field] = column;
    }
    final format = SheetDateFormat.values
        .where((f) => f.name == json['dateFormat'])
        .firstOrNull;
    final source = TypeSource.values
        .where((s) => s.name == json['typeSource'])
        .firstOrNull;
    if (format == null || source == null) return null;

    final account = json['defaultAccountId'];
    return ImportMapping(
      columns: columns,
      dateFormat: format,
      typeSource: source,
      defaultAccountId: account is int ? account : null,
    );
  }

  ImportMapping copyWith({
    Map<ImportField, int>? columns,
    SheetDateFormat? dateFormat,
    TypeSource? typeSource,
    int? Function()? defaultAccountId,
  }) => ImportMapping(
    columns: columns ?? this.columns,
    dateFormat: dateFormat ?? this.dateFormat,
    typeSource: typeSource ?? this.typeSource,
    defaultAccountId: defaultAccountId == null
        ? this.defaultAccountId
        : defaultAccountId(),
  );
}

// Words that give away what a column holds, most specific field first.
const _keywords = <ImportField, List<String>>{
  ImportField.date: ['date', 'তারিখ', 'when', 'day'],
  ImportField.amount: [
    'amount',
    'টাকা',
    'taka',
    'value',
    'price',
    'cost',
    'sum',
  ],
  ImportField.type: ['type', 'in/out', 'income/expense', 'kind', 'ধরন'],
  ImportField.toAccount: [
    'to account',
    'to_account',
    'destination',
    'transfer to',
  ],
  ImportField.account: [
    'account',
    'wallet',
    'method',
    'source',
    'paid from',
    'paid by',
    'অ্যাকাউন্ট',
  ],
  ImportField.category: ['category', 'head', 'group', 'ক্যাটাগরি', 'খাত'],
  ImportField.note: [
    'note',
    'description',
    'details',
    'memo',
    'remark',
    'narration',
    'particulars',
    'বিবরণ',
  ],
};

// Words in the names of the two amount columns of a sheet that keeps income
// and expense apart.
const _incomeColumnWords = [
  'income',
  'credit',
  'deposit',
  'received',
  'আয়',
  'জমা',
];
const _expenseColumnWords = [
  'expense',
  'debit',
  'withdrawal',
  'spent',
  'ব্যয়',
  'খরচ',
];

// Columns with these in the name are about something else than an amount:
// "Income/Expense" is a type, "Expense category" a category.
const _notAnAmountWords = [
  '/',
  'type',
  'categ',
  'account',
  'note',
  'desc',
  'ক্যাটাগরি',
  'অ্যাকাউন্ট',
];

int? _firstAmountColumn(List<String> lower, List<String> words, Set<int> used) {
  for (var column = 0; column < lower.length; column++) {
    if (used.contains(column)) continue;
    final name = lower[column];
    if (_notAnAmountWords.any(name.contains)) continue;
    if (words.any(name.contains)) return column;
  }
  return null;
}

/// A first guess at the mapping from the names in the header row. Each field
/// gets the first column whose name contains one of its keywords, and a column
/// is used for one field only. Fields without a match are left out. A column
/// for income and one for expense are found together, and then there is no
/// single amount column.
Map<ImportField, int> guessColumns(List<String> headers) {
  final lower = [for (final header in headers) header.trim().toLowerCase()];
  final used = <int>{};
  final result = <ImportField, int>{};

  final income = _firstAmountColumn(lower, _incomeColumnWords, used);
  final expense = income == null
      ? null
      : _firstAmountColumn(lower, _expenseColumnWords, {income});
  if (income != null && expense != null) {
    result[ImportField.incomeAmount] = income;
    result[ImportField.expenseAmount] = expense;
    used.addAll([income, expense]);
  }

  for (final entry in _keywords.entries) {
    if (entry.key == ImportField.amount &&
        result.containsKey(ImportField.incomeAmount)) {
      continue;
    }
    for (var column = 0; column < lower.length; column++) {
      if (used.contains(column)) continue;
      if (entry.value.any(lower[column].contains)) {
        result[entry.key] = column;
        used.add(column);
        break;
      }
    }
  }
  return result;
}

const _incomeWords = {
  'income',
  'in',
  'credit',
  'cr',
  'deposit',
  'received',
  '+',
  'আয়',
  'জমা',
};
const _expenseWords = {
  'expense',
  'out',
  'debit',
  'dr',
  'spent',
  'withdrawal',
  'payment',
  '-',
  'ব্যয়',
  'খরচ',
};
const _transferWords = {'transfer', 'transfers', 'ট্রান্সফার'};

/// The transaction type a cell of a "type" column means, or null when it is
/// not one of the known words.
TransactionType? parseTypeText(String raw) {
  final text = raw.trim().toLowerCase();
  if (_incomeWords.contains(text)) return TransactionType.income;
  if (_expenseWords.contains(text)) return TransactionType.expense;
  if (_transferWords.contains(text)) return TransactionType.transfer;
  return null;
}

/// A first mapping for [table]: columns guessed from the header names (none
/// when the file has no header row), the date order found from the dates, and
/// the type taken from a type column if there is one, else from the sign of
/// the amounts when some are negative, else every row an expense.
ImportMapping suggestMapping(
  CsvTable table, {
  required bool hasHeader,
  int? defaultAccountId,
}) {
  final columns = hasHeader
      ? guessColumns(table.headers)
      : <ImportField, int>{};

  final dateColumn = columns[ImportField.date];
  final dateFormat = dateColumn == null
      ? SheetDateFormat.dayMonthYear
      : detectDateFormat(table.rows.map((row) => row[dateColumn])) ??
            SheetDateFormat.dayMonthYear;

  final twoColumns =
      columns.containsKey(ImportField.incomeAmount) &&
      columns.containsKey(ImportField.expenseAmount);
  final amountColumn = columns[ImportField.amount];
  final hasNegativeAmounts =
      amountColumn != null &&
      table.rows.any((row) => (parseSheetAmount(row[amountColumn]) ?? 0) < 0);
  final typeSource = twoColumns
      ? TypeSource.twoColumns
      : columns.containsKey(ImportField.type)
      ? TypeSource.column
      : hasNegativeAmounts
      ? TypeSource.amountSign
      : TypeSource.allExpense;

  return ImportMapping(
    columns: columns,
    dateFormat: dateFormat,
    typeSource: typeSource,
    defaultAccountId: defaultAccountId,
  );
}

/// What is still missing before [mapping] can be used, or null when it is
/// complete. The text is shown to the user.
String? mappingProblem(ImportMapping mapping) {
  if (mapping.columnOf(ImportField.date) == null) {
    return tr('Choose the column that has the date.');
  }
  if (mapping.typeSource == TypeSource.twoColumns) {
    if (mapping.columnOf(ImportField.incomeAmount) == null &&
        mapping.columnOf(ImportField.expenseAmount) == null) {
      return tr(
        'Choose the column that has the income amount, the expense amount, '
        'or both.',
      );
    }
  } else if (mapping.columnOf(ImportField.amount) == null) {
    return tr('Choose the column that has the amount.');
  }
  if (mapping.typeSource == TypeSource.column &&
      mapping.columnOf(ImportField.type) == null) {
    return tr(
      'Choose the column that has the type, or say where the type '
      'comes from.',
    );
  }
  if (mapping.columnOf(ImportField.account) == null &&
      mapping.defaultAccountId == null) {
    return tr('Choose the account these transactions belong to.');
  }
  return null;
}

/// What a file with these [headers] is called when its mapping is saved: the
/// names of the columns, so the next file with the same columns finds it.
String headerSignature(List<String> headers) =>
    [for (final header in headers) header.trim().toLowerCase()].join('|');
