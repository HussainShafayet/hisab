import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

const cash = ExistingAccount(id: 1, name: 'Cash');
const bkash = ExistingAccount(id: 2, name: 'bKash');

const food = ExistingCategory(id: 10, name: 'Food', type: CategoryType.expense);
const groceries = ExistingCategory(
  id: 11,
  name: 'Groceries',
  type: CategoryType.expense,
  parentId: 10,
);
const salary = ExistingCategory(
  id: 20,
  name: 'Salary',
  type: CategoryType.income,
);

ImportContext context({
  List<ExistingAccount> accounts = const [cash, bkash],
  List<ExistingCategory> categories = const [food, groceries, salary],
  Map<String, int> existing = const {},
}) => ImportContext(
  accounts: accounts,
  categories: categories,
  existingKeyCounts: existing,
);

/// Date, Amount, Type, Category, Account, To account, Note
ImportMapping mapping({
  TypeSource typeSource = TypeSource.column,
  SheetDateFormat dateFormat = SheetDateFormat.dayMonthYear,
  int? defaultAccountId,
  Map<ImportField, int>? columns,
}) => ImportMapping(
  columns:
      columns ??
      {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.type: 2,
        ImportField.category: 3,
        ImportField.account: 4,
        ImportField.toAccount: 5,
        ImportField.note: 6,
      },
  dateFormat: dateFormat,
  typeSource: typeSource,
  defaultAccountId: defaultAccountId,
);

CsvTable table(List<List<String>> rows) => CsvTable(
  headers: const [
    'Date',
    'Amount',
    'Type',
    'Category',
    'Account',
    'To account',
    'Note',
  ],
  rows: rows,
);

ImportPlan plan(
  List<List<String>> rows, {
  ImportMapping? map,
  ImportContext? ctx,
}) => buildImportPlan(
  table: table(rows),
  mapping: map ?? mapping(),
  context: ctx ?? context(),
);

void main() {
  group('reading a row', () {
    test('an expense with everything', () {
      final result = plan([
        ['11/10/2026', '1,250.50', 'expense', 'Food', 'Cash', '', 'Lunch'],
      ]);

      final row = result.rows.single;
      expect(row.status, RowStatus.ok);
      expect(row.rowNumber, 1);
      final parsed = row.parsed!;
      expect(parsed.date, DateTime(2026, 10, 11, 12));
      expect(parsed.type, TransactionType.expense);
      expect(parsed.amount, 125050);
      expect(parsed.accountName, 'Cash');
      expect(parsed.categoryPath, ['Food']);
      expect(parsed.note, 'Lunch');
      expect(result.importCount, 1);
    });

    test('an income', () {
      final row = plan([
        ['11/10/2026', '50000', 'Income', 'Salary', 'Cash', '', ''],
      ]).rows.single;

      expect(row.parsed!.type, TransactionType.income);
    });

    test('a transfer has two accounts and no category', () {
      final row = plan([
        [
          '11/10/2026',
          '1000',
          'transfer',
          'ignored',
          'Cash',
          'bKash',
          'Cash out',
        ],
      ]).rows.single;

      expect(row.status, RowStatus.ok);
      expect(row.parsed!.type, TransactionType.transfer);
      expect(row.parsed!.accountName, 'Cash');
      expect(row.parsed!.toAccountName, 'bKash');
      expect(row.parsed!.categoryPath, isEmpty);
    });

    test('the amount is kept positive and the type comes from the sign', () {
      final result = plan([
        ['11/10/2026', '-250', '', 'Food', 'Cash', '', ''],
        ['12/10/2026', '1000', '', 'Salary', 'Cash', '', ''],
      ], map: mapping(typeSource: TypeSource.amountSign));

      expect(result.rows[0].parsed!.type, TransactionType.expense);
      expect(result.rows[0].parsed!.amount, 25000);
      expect(result.rows[1].parsed!.type, TransactionType.income);
      expect(result.rows[1].parsed!.amount, 100000);
    });

    test('all rows can be expenses or all income', () {
      final rows = [
        ['11/10/2026', '250', 'whatever', 'Food', 'Cash', '', ''],
      ];

      expect(
        plan(
          rows,
          map: mapping(typeSource: TypeSource.allExpense),
        ).rows.single.parsed!.type,
        TransactionType.expense,
      );
      expect(
        plan(
          rows,
          map: mapping(typeSource: TypeSource.allIncome),
        ).rows.single.parsed!.type,
        TransactionType.income,
      );
    });

    test('a note that is too long is cut', () {
      final row = plan([
        ['11/10/2026', '10', 'expense', 'Food', 'Cash', '', 'x' * 600],
      ]).rows.single;

      expect(row.parsed!.note.length, maxImportNoteLength);
    });

    test('numbers the rows from 1, not counting the header', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Food', 'Cash', '', ''],
        ['bad', '10', 'expense', 'Food', 'Cash', '', ''],
        ['13/10/2026', '30', 'expense', 'Food', 'Cash', '', ''],
      ]);

      expect(result.rows.map((r) => r.rowNumber), [1, 2, 3]);
      expect(result.rows.map((r) => r.status), [
        RowStatus.ok,
        RowStatus.error,
        RowStatus.ok,
      ]);
    });
  });

  group('rows that cannot be read', () {
    String errorOf(List<String> row, {ImportMapping? map}) {
      final result = plan([row], map: map);
      expect(
        result.rows.single.status,
        RowStatus.error,
        reason: row.toString(),
      );
      expect(result.rows.single.parsed, isNull);
      return result.rows.single.error!;
    }

    test('a missing or wrong date', () {
      expect(
        errorOf(['', '10', 'expense', 'Food', 'Cash', '', '']),
        contains('date is empty'),
      );
      expect(
        errorOf(['31/02/2026', '10', 'expense', 'Food', 'Cash', '', '']),
        contains('"31/02/2026" is not a Day/Month/Year date'),
      );
      expect(
        errorOf(['2026-10-11', '10', 'expense', 'Food', 'Cash', '', '']),
        contains('not a Day/Month/Year'),
      );
    });

    test('a missing, wrong or zero amount', () {
      expect(
        errorOf(['11/10/2026', '', 'expense', 'Food', 'Cash', '', '']),
        contains('amount is empty'),
      );
      expect(
        errorOf(['11/10/2026', 'lots', 'expense', 'Food', 'Cash', '', '']),
        contains('"lots" is not an amount'),
      );
      expect(
        errorOf(['11/10/2026', '0', 'expense', 'Food', 'Cash', '', '']),
        contains('zero'),
      );
    });

    test('an unknown or empty type', () {
      expect(
        errorOf(['11/10/2026', '10', 'maybe', 'Food', 'Cash', '', '']),
        contains('"maybe" is not income'),
      );
      expect(
        errorOf(['11/10/2026', '10', '', 'Food', 'Cash', '', '']),
        contains('type is empty'),
      );
    });

    test('no account and no default account', () {
      expect(
        errorOf(['11/10/2026', '10', 'expense', 'Food', '', '', '']),
        contains('no account'),
      );
    });

    test('a transfer without a destination or to the same account', () {
      expect(
        errorOf(['11/10/2026', '10', 'transfer', '', 'Cash', '', '']),
        contains('"to account"'),
      );
      expect(
        errorOf(['11/10/2026', '10', 'transfer', '', 'Cash', ' cash ', '']),
        contains('two different accounts'),
      );
    });

    test('a category more than five levels deep', () {
      expect(
        errorOf([
          '11/10/2026',
          '10',
          'expense',
          'A > B > C > D > E > F',
          'Cash',
          '',
          '',
        ]),
        contains('more than 5 levels'),
      );
    });

    test('an error does not stop the rows after it', () {
      final result = plan([
        ['bad', '10', 'expense', 'Food', 'Cash', '', ''],
        ['12/10/2026', '20', 'expense', 'Food', 'Cash', '', ''],
      ]);

      expect(result.errorCount, 1);
      expect(result.importCount, 1);
    });
  });

  group('accounts', () {
    test('an account is matched ignoring case and spaces', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Food', '  BKASH ', '', ''],
      ]);

      expect(result.newAccounts, isEmpty);
    });

    test('an unknown account is created once, however often it appears', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Food', 'Nagad', '', ''],
        ['12/10/2026', '20', 'expense', 'Food', 'nagad', '', ''],
        ['13/10/2026', '30', 'expense', 'Food', 'Rocket', '', ''],
      ]);

      expect(result.newAccounts, ['Nagad', 'Rocket']);
    });

    test('a new "to account" is created too', () {
      final result = plan([
        ['11/10/2026', '10', 'transfer', '', 'Cash', 'Savings', ''],
      ]);

      expect(result.newAccounts, ['Savings']);
    });

    test('the default account is used for rows without one', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Food', '', '', ''],
        ['12/10/2026', '20', 'expense', 'Food', 'bKash', '', ''],
      ], map: mapping(defaultAccountId: 1));

      expect(result.rows[0].parsed!.accountName, 'Cash');
      expect(result.rows[1].parsed!.accountName, 'bKash');
    });

    test('with no account column every row uses the default account', () {
      final result = plan(
        [
          ['11/10/2026', '10', 'expense', 'Food', 'ignored', '', ''],
        ],
        map: mapping(
          defaultAccountId: 2,
          columns: {
            ImportField.date: 0,
            ImportField.amount: 1,
            ImportField.type: 2,
            ImportField.category: 3,
          },
        ),
      );

      expect(result.rows.single.parsed!.accountName, 'bKash');
      expect(result.newAccounts, isEmpty);
    });

    test('accounts of skipped rows are not created', () {
      final result = plan([
        ['bad', '10', 'expense', 'Food', 'Nagad', '', ''],
      ]);

      expect(result.newAccounts, isEmpty);
    });
  });

  group('categories', () {
    test('a known category needs nothing new', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'food', 'Cash', '', ''],
        ['12/10/2026', '10', 'income', 'SALARY', 'Cash', '', ''],
      ]);

      expect(result.newCategories, isEmpty);
    });

    test('a sub-category is found by its own name or by its path', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Groceries', 'Cash', '', ''],
        ['12/10/2026', '10', 'expense', 'Food > Groceries', 'Cash', '', ''],
        ['13/10/2026', '10', 'expense', 'Food › groceries', 'Cash', '', ''],
      ]);

      expect(result.newCategories, isEmpty);
    });

    test('an unknown category is created once', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Pets', 'Cash', '', ''],
        ['12/10/2026', '10', 'expense', 'pets', 'Cash', '', ''],
      ]);

      expect(result.newCategories.map((c) => c.label), ['Pets']);
      expect(result.newCategories.single.type, CategoryType.expense);
    });

    test('an unknown sub-category under a known parent is created', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Food > Restaurants', 'Cash', '', ''],
      ]);

      expect(result.newCategories.single.path, ['Food', 'Restaurants']);
    });

    test('the same name as income and expense are two categories', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Gift', 'Cash', '', ''],
        ['12/10/2026', '10', 'income', 'Gift', 'Cash', '', ''],
      ]);

      expect(result.newCategories.map((c) => c.type), [
        CategoryType.expense,
        CategoryType.income,
      ]);
    });

    test('a row with no category goes to Other, or Other income', () {
      final result = plan([
        ['11/10/2026', '10', 'expense', '', 'Cash', '', ''],
        ['12/10/2026', '10', 'income', '', 'Cash', '', ''],
      ]);

      expect(result.rows[0].parsed!.categoryPath, [defaultExpenseCategoryName]);
      expect(result.rows[1].parsed!.categoryPath, [defaultIncomeCategoryName]);
      expect(result.newCategories.map((c) => c.label), [
        'Other',
        'Other income',
      ]);
    });

    test('Other is not created when it already exists', () {
      final result = plan(
        [
          ['11/10/2026', '10', 'expense', '', 'Cash', '', ''],
        ],
        ctx: context(
          categories: [
            const ExistingCategory(
              id: 30,
              name: 'Other',
              type: CategoryType.expense,
            ),
          ],
        ),
      );

      expect(result.newCategories, isEmpty);
    });

    test('with no category column every row goes to Other', () {
      final result = plan(
        [
          ['11/10/2026', '10', 'expense', 'Food', 'Cash', '', ''],
        ],
        map: mapping(
          columns: {
            ImportField.date: 0,
            ImportField.amount: 1,
            ImportField.type: 2,
            ImportField.account: 4,
          },
        ),
      );

      expect(result.rows.single.parsed!.categoryPath, ['Other']);
    });

    test('a transfer needs no category', () {
      final result = plan([
        ['11/10/2026', '10', 'transfer', 'Pets', 'Cash', 'bKash', ''],
      ]);

      expect(result.newCategories, isEmpty);
    });

    test('an archived category is still found', () {
      final result = plan(
        [
          ['11/10/2026', '10', 'expense', 'Old', 'Cash', '', ''],
        ],
        ctx: context(
          categories: [
            const ExistingCategory(
              id: 40,
              name: 'Old',
              type: CategoryType.expense,
              isArchived: true,
            ),
          ],
        ),
      );

      expect(result.newCategories, isEmpty);
    });

    test('categories of duplicate rows are not created', () {
      final key = duplicateKey(
        date: DateTime(2026, 10, 11),
        type: TransactionType.expense,
        amount: 1000,
        accountId: 1,
        note: '',
      );
      final result = plan([
        ['11/10/2026', '10', 'expense', 'Pets', 'Cash', '', ''],
      ], ctx: context(existing: {key: 1}));

      expect(result.duplicateCount, 1);
      expect(result.newCategories, isEmpty);
    });
  });

  group('duplicates', () {
    String key(
      DateTime date,
      int amount, {
      int account = 1,
      String note = '',
      TransactionType type = TransactionType.expense,
      int? to,
    }) => duplicateKey(
      date: date,
      type: type,
      amount: amount,
      accountId: account,
      note: note,
      toAccountId: to,
    );

    test('a row the app already has is skipped', () {
      final result = plan(
        [
          ['11/10/2026', '250', 'expense', 'Food', 'Cash', '', 'Lunch'],
        ],
        ctx: context(
          existing: {
            key(DateTime(2026, 10, 11, 9, 30), 25000, note: 'Lunch'): 1,
          },
        ),
      );

      expect(result.rows.single.status, RowStatus.duplicate);
      expect(result.rows.single.parsed, isNotNull);
      expect(result.importCount, 0);
      expect(result.duplicateCount, 1);
    });

    test(
      'the time of day and the category do not matter, the note case does not',
      () {
        final result = plan(
          [
            [
              '11/10/2026 23:59',
              '250',
              'expense',
              'Pets',
              'Cash',
              '',
              '  LUNCH ',
            ],
          ],
          ctx: context(
            existing: {key(DateTime(2026, 10, 11, 8), 25000, note: 'lunch'): 1},
          ),
        );

        expect(result.rows.single.status, RowStatus.duplicate);
      },
    );

    test('another day, amount, account, type or note is not a duplicate', () {
      final existing = {key(DateTime(2026, 10, 11), 25000, note: 'Lunch'): 1};
      final result = plan([
        ['12/10/2026', '250', 'expense', 'Food', 'Cash', '', 'Lunch'], // day
        ['11/10/2026', '251', 'expense', 'Food', 'Cash', '', 'Lunch'], // amount
        [
          '11/10/2026',
          '250',
          'expense',
          'Food',
          'bKash',
          '',
          'Lunch',
        ], // account
        ['11/10/2026', '250', 'income', 'Salary', 'Cash', '', 'Lunch'], // type
        ['11/10/2026', '250', 'expense', 'Food', 'Cash', '', 'Dinner'], // note
      ], ctx: context(existing: existing));

      expect(result.rows.every((r) => r.status == RowStatus.ok), isTrue);
    });

    test('equal rows in the file are all imported when the app has none', () {
      final result = plan([
        ['11/10/2026', '60', 'expense', 'Food', 'Cash', '', 'Rickshaw'],
        ['11/10/2026', '60', 'expense', 'Food', 'Cash', '', 'Rickshaw'],
      ]);

      expect(result.importCount, 2);
    });

    test('each existing transaction matches only one row of the file', () {
      final existing = {key(DateTime(2026, 10, 11), 6000, note: 'Rickshaw'): 1};
      final result = plan([
        ['11/10/2026', '60', 'expense', 'Food', 'Cash', '', 'Rickshaw'],
        ['11/10/2026', '60', 'expense', 'Food', 'Cash', '', 'Rickshaw'],
      ], ctx: context(existing: existing));

      expect(result.rows.map((r) => r.status), [
        RowStatus.duplicate,
        RowStatus.ok,
      ]);
    });

    test('importing the same file twice finds every row the second time', () {
      final rows = [
        ['11/10/2026', '60', 'expense', 'Food', 'Cash', '', 'Rickshaw'],
        ['11/10/2026', '60', 'expense', 'Food', 'Cash', '', 'Rickshaw'],
        ['12/10/2026', '500', 'income', 'Salary', 'bKash', '', ''],
      ];
      final second = plan(
        rows,
        ctx: context(
          existing: {
            key(DateTime(2026, 10, 11), 6000, note: 'Rickshaw'): 2,
            key(
              DateTime(2026, 10, 12),
              50000,
              account: 2,
              type: TransactionType.income,
            ): 1,
          },
        ),
      );

      expect(second.duplicateCount, 3);
      expect(second.importCount, 0);
    });

    test('a transfer is a duplicate only for the same two accounts', () {
      final existing = {
        key(
          DateTime(2026, 10, 11),
          100000,
          type: TransactionType.transfer,
          to: 2,
        ): 1,
      };
      final result = plan([
        ['11/10/2026', '1000', 'transfer', '', 'Cash', 'bKash', ''],
        ['11/10/2026', '1000', 'transfer', '', 'bKash', 'Cash', ''],
      ], ctx: context(existing: existing));

      expect(result.rows.map((r) => r.status), [
        RowStatus.duplicate,
        RowStatus.ok,
      ]);
    });

    test('a row in a new account cannot be a duplicate', () {
      final result = plan([
        ['11/10/2026', '250', 'expense', 'Food', 'Nagad', '', ''],
      ], ctx: context(existing: {key(DateTime(2026, 10, 11), 25000): 1}));

      expect(result.rows.single.status, RowStatus.ok);
    });
  });

  group('duplicateKey', () {
    test('is the same for the same day whatever the time', () {
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 11, 1),
          type: TransactionType.expense,
          amount: 5,
          accountId: 1,
          note: 'a',
        ),
        duplicateKey(
          date: DateTime(2026, 10, 11, 23, 59),
          type: TransactionType.expense,
          amount: 5,
          accountId: 1,
          note: 'a',
        ),
      );
    });

    test('differs for each part that matters', () {
      final base = duplicateKey(
        date: DateTime(2026, 10, 11),
        type: TransactionType.expense,
        amount: 5,
        accountId: 1,
        note: 'a',
      );
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 12),
          type: TransactionType.expense,
          amount: 5,
          accountId: 1,
          note: 'a',
        ),
        isNot(base),
      );
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 11),
          type: TransactionType.income,
          amount: 5,
          accountId: 1,
          note: 'a',
        ),
        isNot(base),
      );
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 11),
          type: TransactionType.expense,
          amount: 6,
          accountId: 1,
          note: 'a',
        ),
        isNot(base),
      );
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 11),
          type: TransactionType.expense,
          amount: 5,
          accountId: 2,
          note: 'a',
        ),
        isNot(base),
      );
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 11),
          type: TransactionType.expense,
          amount: 5,
          accountId: 1,
          note: 'b',
        ),
        isNot(base),
      );
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 11),
          type: TransactionType.expense,
          amount: 5,
          accountId: 1,
          note: 'a',
          toAccountId: 2,
        ),
        isNot(base),
      );
    });

    test('ignores case and extra spaces in the note', () {
      expect(
        duplicateKey(
          date: DateTime(2026, 10, 11),
          type: TransactionType.expense,
          amount: 5,
          accountId: 1,
          note: ' Lunch   with  Rahim ',
        ),
        duplicateKey(
          date: DateTime(2026, 10, 11),
          type: TransactionType.expense,
          amount: 5,
          accountId: 1,
          note: 'lunch with rahim',
        ),
      );
    });
  });

  group('CategoryResolver', () {
    test(
      'prefers an active category over an archived one of the same name',
      () {
        final resolver = CategoryResolver([
          const ExistingCategory(
            id: 1,
            name: 'Fun',
            type: CategoryType.expense,
            isArchived: true,
          ),
          const ExistingCategory(
            id: 2,
            name: 'Fun',
            type: CategoryType.expense,
          ),
        ]);

        expect(resolver.findTopLevel('fun', CategoryType.expense), 2);
      },
    );

    test(
      'finds a top-level category before a sub-category of the same name',
      () {
        final resolver = CategoryResolver([
          const ExistingCategory(
            id: 1,
            name: 'Other',
            type: CategoryType.expense,
            parentId: 9,
          ),
          const ExistingCategory(
            id: 2,
            name: 'Other',
            type: CategoryType.expense,
          ),
        ]);

        expect(resolver.findAny('Other', CategoryType.expense), 2);
      },
    );

    test('knows categories added while importing', () {
      final resolver = CategoryResolver(const []);
      expect(resolver.find(['Pets'], CategoryType.expense), isNull);

      resolver.add(
        const ExistingCategory(id: 5, name: 'Pets', type: CategoryType.expense),
      );

      expect(resolver.find(['Pets'], CategoryType.expense), 5);
    });

    test('a path needs its parent', () {
      final resolver = CategoryResolver(const [
        ExistingCategory(id: 1, name: 'Food', type: CategoryType.expense),
        ExistingCategory(
          id: 2,
          name: 'Groceries',
          type: CategoryType.expense,
          parentId: 1,
        ),
      ]);

      expect(resolver.find(['Food', 'Groceries'], CategoryType.expense), 2);
      expect(
        resolver.find(['Transport', 'Groceries'], CategoryType.expense),
        isNull,
      );
      expect(resolver.find(['Food', 'Fuel'], CategoryType.expense), isNull);
    });

    test('splitCategoryPath trims and drops empty parts', () {
      expect(splitCategoryPath(' Food > Groceries '), ['Food', 'Groceries']);
      expect(splitCategoryPath('Food›Groceries'), ['Food', 'Groceries']);
      expect(splitCategoryPath('Food >'), ['Food']);
      expect(splitCategoryPath('  '), isEmpty);
      expect(splitCategoryPath('Fees/Charges'), ['Fees/Charges']);
    });
  });

  group('guessAccountType', () {
    test('knows the usual names', () {
      expect(guessAccountType('bKash'), AccountType.mobileBanking);
      expect(guessAccountType('Nagad Personal'), AccountType.mobileBanking);
      expect(guessAccountType('DBBL Rocket'), AccountType.mobileBanking);
      expect(guessAccountType('City Bank'), AccountType.bank);
      expect(guessAccountType('Savings'), AccountType.bank);
      expect(guessAccountType('Visa Card'), AccountType.card);
      expect(guessAccountType('Cash'), AccountType.cash);
      expect(guessAccountType('Wallet'), AccountType.cash);
      expect(guessAccountType('Something else'), AccountType.cash);
    });
  });
}
