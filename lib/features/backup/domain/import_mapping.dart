import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/sheet_amount.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The things a CSV row can say about a transaction.
enum ImportField {
  date('Date', isRequired: true),
  amount('Amount', isRequired: true),
  type('Type (income, expense, transfer)'),
  category('Category'),
  account('Account'),
  toAccount('To account (transfers)'),
  note('Note or description');

  const ImportField(this.label, {this.isRequired = false});

  final String label;
  final bool isRequired;
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
  allIncome('All rows are income');

  const TypeSource(this.label);

  final String label;
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

/// A first guess at the mapping from the names in the header row. Each field
/// gets the first column whose name contains one of its keywords, and a column
/// is used for one field only. Fields without a match are left out.
Map<ImportField, int> guessColumns(List<String> headers) {
  final lower = [for (final header in headers) header.trim().toLowerCase()];
  final used = <int>{};
  final result = <ImportField, int>{};

  for (final entry in _keywords.entries) {
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

  final amountColumn = columns[ImportField.amount];
  final hasNegativeAmounts =
      amountColumn != null &&
      table.rows.any((row) => (parseSheetAmount(row[amountColumn]) ?? 0) < 0);
  final typeSource = columns.containsKey(ImportField.type)
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
    return 'Choose the column that has the date.';
  }
  if (mapping.columnOf(ImportField.amount) == null) {
    return 'Choose the column that has the amount.';
  }
  if (mapping.typeSource == TypeSource.column &&
      mapping.columnOf(ImportField.type) == null) {
    return 'Choose the column that has the type, or say where the type '
        'comes from.';
  }
  if (mapping.columnOf(ImportField.account) == null &&
      mapping.defaultAccountId == null) {
    return 'Choose the account these transactions belong to.';
  }
  return null;
}
