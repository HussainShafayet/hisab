import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

const cash = ExistingAccount(id: 1, name: 'Cash');
const bkash = ExistingAccount(id: 2, name: 'bKash');
const hidden = ExistingAccount(
  id: 3,
  name: 'Old records',
  includeInTotal: false,
);

const food = ExistingCategory(id: 10, name: 'Food', type: CategoryType.expense);
const transport = ExistingCategory(
  id: 12,
  name: 'Transport',
  type: CategoryType.expense,
);
const salary = ExistingCategory(
  id: 20,
  name: 'Salary',
  type: CategoryType.income,
);

ImportContext context({
  List<ExistingAccount> accounts = const [cash, bkash, hidden],
  List<ExistingCategory> categories = const [food, transport, salary],
  Map<String, int> existing = const {},
}) => ImportContext(
  accounts: accounts,
  categories: categories,
  existingKeyCounts: existing,
);

/// Date, Income, Expense, Category, Account
const twoColumnHeaders = ['Date', 'Income', 'Expense', 'Category', 'Account'];
final twoColumnMapping = ImportMapping(
  columns: {
    ImportField.date: 0,
    ImportField.incomeAmount: 1,
    ImportField.expenseAmount: 2,
    ImportField.category: 3,
    ImportField.account: 4,
  },
  dateFormat: SheetDateFormat.dayMonthYear,
  typeSource: TypeSource.twoColumns,
);

ImportPlan twoColumnPlan(List<List<String>> rows) => buildImportPlan(
  table: CsvTable(headers: twoColumnHeaders, rows: rows),
  mapping: twoColumnMapping,
  context: context(),
);

/// Date, Amount, Type, Category, Account, To account
const plainHeaders = ['Date', 'Amount', 'Type', 'Category', 'Account', 'To'];
final plainMapping = ImportMapping(
  columns: {
    ImportField.date: 0,
    ImportField.amount: 1,
    ImportField.type: 2,
    ImportField.category: 3,
    ImportField.account: 4,
    ImportField.toAccount: 5,
  },
  dateFormat: SheetDateFormat.dayMonthYear,
  typeSource: TypeSource.column,
);

ImportPlan plainPlan(
  List<List<String>> rows, {
  ImportContext? ctx,
  Map<String, int> categoryMap = const {},
}) => buildImportPlan(
  table: CsvTable(headers: plainHeaders, rows: rows),
  mapping: plainMapping,
  context: ctx ?? context(),
  categoryMap: categoryMap,
);

void main() {
  group('a column for income and one for expense', () {
    test('are found by their names, and there is no one amount column', () {
      final columns = guessColumns(['Date', 'Income', 'Expense', 'Note']);

      expect(columns[ImportField.incomeAmount], 1);
      expect(columns[ImportField.expenseAmount], 2);
      expect(columns.containsKey(ImportField.amount), isFalse);
    });

    test('the suggestion takes the type from the two columns', () {
      final table = CsvTable(
        headers: const ['Date', 'Credit', 'Debit'],
        rows: const [
          ['11/10/2026', '500', ''],
        ],
      );

      final mapping = suggestMapping(table, hasHeader: true);

      expect(mapping.typeSource, TypeSource.twoColumns);
    });

    test('an amount column with a type column is not read as two', () {
      final columns = guessColumns(['Date', 'Amount', 'Income/Expense']);

      expect(columns[ImportField.amount], 1);
      expect(columns[ImportField.type], 2);
      expect(columns.containsKey(ImportField.incomeAmount), isFalse);
    });

    test('a category or note column is not taken for an amount', () {
      final columns = guessColumns([
        'Date',
        'Income',
        'Expense category',
        'Amount',
      ]);

      expect(columns.containsKey(ImportField.incomeAmount), isFalse);
      expect(columns[ImportField.amount], 3);
    });

    test('only the fields that are asked for are shown', () {
      expect(ImportField.amount.isAskedFor(TypeSource.column), isTrue);
      expect(ImportField.amount.isAskedFor(TypeSource.twoColumns), isFalse);
      expect(ImportField.incomeAmount.isAskedFor(TypeSource.column), isFalse);
      expect(
        ImportField.expenseAmount.isAskedFor(TypeSource.twoColumns),
        isTrue,
      );
      expect(ImportField.date.isAskedFor(TypeSource.twoColumns), isTrue);
    });

    test('one of the two columns is enough, none is a problem', () {
      ImportMapping mappingWith(Map<ImportField, int> columns) => ImportMapping(
        columns: {ImportField.date: 0, ...columns},
        dateFormat: SheetDateFormat.dayMonthYear,
        typeSource: TypeSource.twoColumns,
        defaultAccountId: 1,
      );

      expect(mappingProblem(mappingWith({})), isNotNull);
      expect(
        mappingProblem(mappingWith({ImportField.incomeAmount: 1})),
        isNull,
      );
      expect(
        mappingProblem(mappingWith({ImportField.expenseAmount: 2})),
        isNull,
      );
    });

    test('each row is income or expense by the column it fills', () {
      final result = twoColumnPlan([
        ['11/10/2026', '1,000', '', 'Salary', 'Cash'],
        ['12/10/2026', '', '250', 'Food', 'Cash'],
        ['13/10/2026', '', '-50', 'Food', 'Cash'],
      ]);

      final rows = result.rows.map((r) => r.parsed!).toList();
      expect(rows[0].type, TransactionType.income);
      expect(rows[0].amount, 100000);
      expect(rows[1].type, TransactionType.expense);
      expect(rows[1].amount, 25000);
      // A sign in the expense column does not turn it into income.
      expect(rows[2].type, TransactionType.expense);
      expect(rows[2].amount, 5000);
    });

    test('a row that fills both, or neither, cannot be read', () {
      final result = twoColumnPlan([
        ['11/10/2026', '100', '50', 'Food', 'Cash'],
        ['12/10/2026', '', '', 'Food', 'Cash'],
        ['13/10/2026', '0', '', 'Food', 'Cash'],
        ['14/10/2026', '', 'abc', 'Food', 'Cash'],
      ]);

      expect(result.errorCount, 4);
      expect(result.rows[0].error, contains('Both the income and the expense'));
      expect(result.rows[1].error, 'The amount is empty.');
      expect(result.rows[2].error, 'The amount is zero.');
      expect(result.rows[3].error, '"abc" is not an amount.');
    });
  });

  group('saving a mapping', () {
    test('is read back as it was', () {
      final mapping = ImportMapping(
        columns: {ImportField.date: 0, ImportField.amount: 2},
        dateFormat: SheetDateFormat.yearMonthDay,
        typeSource: TypeSource.amountSign,
        defaultAccountId: 7,
      );

      final back = ImportMapping.fromJson(mapping.toJson(), columnCount: 5)!;

      expect(back.columns, mapping.columns);
      expect(back.dateFormat, SheetDateFormat.yearMonthDay);
      expect(back.typeSource, TypeSource.amountSign);
      expect(back.defaultAccountId, 7);
    });

    test('is dropped when it does not fit the file', () {
      final json = ImportMapping(
        columns: {ImportField.date: 0, ImportField.amount: 4},
        dateFormat: SheetDateFormat.dayMonthYear,
        typeSource: TypeSource.allExpense,
      ).toJson();

      expect(ImportMapping.fromJson(json, columnCount: 4), isNull);
      expect(ImportMapping.fromJson(json, columnCount: 5), isNotNull);
    });

    test('is dropped when it is damaged', () {
      expect(ImportMapping.fromJson('text', columnCount: 5), isNull);
      expect(ImportMapping.fromJson({'columns': 3}, columnCount: 5), isNull);
      expect(
        ImportMapping.fromJson({
          'columns': {'nothing': 1},
          'dateFormat': 'dayMonthYear',
          'typeSource': 'allExpense',
        }, columnCount: 5),
        isNull,
      );
      expect(
        ImportMapping.fromJson({
          'columns': {'date': 0},
          'dateFormat': 'someday',
          'typeSource': 'allExpense',
        }, columnCount: 5),
        isNull,
      );
    });

    test('is found by the names of the columns, ignoring case and spaces', () {
      expect(
        headerSignature([' Date ', 'AMOUNT']),
        headerSignature(['date', 'amount']),
      );
      expect(
        headerSignature(['date', 'amount']),
        isNot(headerSignature(['amount', 'date'])),
      );
    });
  });

  group('what an import does to the balances', () {
    test('income adds, expense takes, a transfer moves', () {
      final result = plainPlan([
        ['11/10/2026', '250', 'income', 'Salary', 'Cash', ''],
        ['12/10/2026', '100', 'expense', 'Food', 'Cash', ''],
        ['13/10/2026', '40', 'transfer', '', 'Cash', 'bKash'],
      ]);

      final byName = {for (final c in result.accountChanges) c.name: c};
      expect(byName['Cash']!.change, 25000 - 10000 - 4000);
      expect(byName['bKash']!.change, 4000);
      expect(byName['Cash']!.isNew, isFalse);
    });

    test('an account that is new starts from nothing', () {
      final result = plainPlan([
        ['11/10/2026', '100', 'expense', 'Food', 'Wallet', ''],
      ]);

      final change = result.accountChanges.single;
      expect(change.name, 'Wallet');
      expect(change.isNew, isTrue);
      expect(change.includeInTotal, isTrue);
      expect(change.change, -10000);
    });

    test('says when an account is left out of the total', () {
      final result = plainPlan([
        ['11/10/2026', '100', 'income', 'Salary', 'old records', ''],
      ]);

      final change = result.accountChanges.single;
      expect(change.name, 'Old records');
      expect(change.includeInTotal, isFalse);
    });

    test('rows that are skipped do not count', () {
      final key = duplicateKey(
        date: DateTime(2026, 10, 11),
        type: TransactionType.expense,
        amount: 10000,
        accountId: 1,
        note: '',
      );
      final result = plainPlan([
        ['11/10/2026', '100', 'expense', 'Food', 'Cash', ''],
        ['12/10/2026', 'abc', 'expense', 'Food', 'Cash', ''],
        ['13/10/2026', '30', 'expense', 'Food', 'Cash', ''],
      ], ctx: context(existing: {key: 1}));

      expect(result.duplicateCount, 1);
      expect(result.accountChanges.single.change, -3000);
    });

    test('are listed by name', () {
      final result = plainPlan([
        ['11/10/2026', '1', 'expense', 'Food', 'bKash', ''],
        ['11/10/2026', '1', 'expense', 'Food', 'Cash', ''],
      ]);

      expect(result.accountChanges.map((c) => c.name), ['bKash', 'Cash']);
    });
  });

  group('categories that look like the ones the app has', () {
    test('a longer or shorter name is matched', () {
      expect(
        similarCategory('Transportation', CategoryType.expense, [
          food,
          transport,
        ])?.id,
        transport.id,
      );
      expect(
        similarCategory('Foods', CategoryType.expense, [food])?.id,
        food.id,
      );
    });

    test('a plural is the same word: Utility and Utilities', () {
      const utilities = ExistingCategory(
        id: 40,
        name: 'Utilities',
        type: CategoryType.expense,
      );

      expect(
        similarCategory('Utility', CategoryType.expense, [utilities])?.id,
        utilities.id,
      );
      expect(
        similarCategory('Utilities', CategoryType.expense, [
          const ExistingCategory(
            id: 41,
            name: 'Utility',
            type: CategoryType.expense,
          ),
        ])?.id,
        41,
      );
    });

    test('only the same type, and not archived or very short names', () {
      expect(
        similarCategory('Transportation', CategoryType.income, [transport]),
        isNull,
      );
      expect(
        similarCategory('Transportation', CategoryType.expense, [
          const ExistingCategory(
            id: 1,
            name: 'Transport',
            type: CategoryType.expense,
            isArchived: true,
          ),
        ]),
        isNull,
      );
      expect(similarCategory('Car', CategoryType.expense, [food]), isNull);
      expect(similarCategory('Rent', CategoryType.expense, [food]), isNull);
    });

    test('the closest in length comes first', () {
      const longer = ExistingCategory(
        id: 30,
        name: 'Public transportation',
        type: CategoryType.expense,
      );
      expect(
        similarCategory('Transportation', CategoryType.expense, [
          longer,
          transport,
        ])?.id,
        transport.id,
      );
    });

    test('a new category of the plan carries the suggestion', () {
      final result = plainPlan([
        ['11/10/2026', '100', 'expense', 'Transportation', 'Cash', ''],
        ['11/10/2026', '100', 'expense', 'Pets', 'Cash', ''],
        ['11/10/2026', '100', 'expense', 'Transportation > Bus', 'Cash', ''],
      ]);

      final byLabel = {for (final c in result.newCategories) c.label: c};
      expect(byLabel['Transportation']!.suggestion?.name, 'Transport');
      expect(byLabel['Pets']!.suggestion, isNull);
      // A sub-category is never suggested.
      expect(byLabel['Transportation > Bus']!.suggestion, isNull);
    });

    test('a category matched by hand is not made', () {
      final key = categoryKey(CategoryType.expense, ['Transportation']);
      final rows = [
        ['11/10/2026', '100', 'expense', 'Transportation', 'Cash', ''],
      ];

      expect(plainPlan(rows).newCategories, hasLength(1));
      expect(
        plainPlan(rows, categoryMap: {key: transport.id}).newCategories,
        isEmpty,
      );
      // An id that is not a category of the app is ignored.
      expect(
        plainPlan(rows, categoryMap: {key: 999}).newCategories,
        hasLength(1),
      );
    });
  });

  group('dates that do not fit the rows around them', () {
    List<List<String>> rowsWithDates(List<String> dates) => [
      for (final date in dates) [date, '10', 'expense', 'Food', 'Cash', ''],
    ];

    test('day and month the wrong way round is noticed', () {
      final result = plainPlan(
        rowsWithDates([
          '10/08/2024',
          '11/08/2024',
          '08/11/2024',
          '12/08/2024',
          '12/08/2024',
        ]),
      );

      expect(result.warningCount, 1);
      expect(result.rows[2].warning, startsWith('This date may have'));
      expect(result.rows[2].warning, contains('11 Aug 2024'));
      // The row is still imported.
      expect(result.rows[2].status, RowStatus.ok);
      expect(result.importCount, 5);
    });

    test('a date that is just far away says so', () {
      final result = plainPlan(
        rowsWithDates([
          '10/08/2024',
          '11/08/2024',
          '30/05/2023',
          '12/08/2024',
          '12/08/2024',
        ]),
      );

      expect(result.warningCount, 1);
      expect(result.rows[2].warning, startsWith('This date is far from'));
    });

    test('the first and the last row are looked at too', () {
      final result = plainPlan(
        rowsWithDates([
          '08/11/2024',
          '10/08/2024',
          '11/08/2024',
          '12/08/2024',
          '13/08/2024',
          '30/05/2023',
        ]),
      );

      expect(result.rows[0].warning, isNotNull);
      expect(result.rows[5].warning, isNotNull);
      expect(result.warningCount, 2);
    });

    test('a file that jumps from date to date is left alone', () {
      final result = plainPlan(
        rowsWithDates([
          '10/01/2024',
          '10/04/2024',
          '10/07/2024',
          '10/10/2024',
          '10/01/2025',
        ]),
      );

      expect(result.warningCount, 0);
    });

    test('a file in no order, within a month, is left alone', () {
      final result = plainPlan(
        rowsWithDates([
          '20/08/2024',
          '03/08/2024',
          '15/08/2024',
          '01/08/2024',
          '28/08/2024',
        ]),
      );

      expect(result.warningCount, 0);
    });

    test('too few rows to tell', () {
      expect(
        plainPlan(rowsWithDates(['10/08/2024', '08/11/2024'])).warningCount,
        0,
      );
    });
  });
}
