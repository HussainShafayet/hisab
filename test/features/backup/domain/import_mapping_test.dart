import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

void main() {
  group('guessColumns', () {
    test('finds the usual columns by their names', () {
      final guess = guessColumns([
        'Date',
        'Description',
        'Category',
        'Amount',
        'Account',
      ]);

      expect(guess, {
        ImportField.date: 0,
        ImportField.note: 1,
        ImportField.category: 2,
        ImportField.amount: 3,
        ImportField.account: 4,
      });
    });

    test('ignores case and extra words', () {
      final guess = guessColumns([
        'TRANSACTION DATE',
        'Total Amount (BDT)',
        'Paid From',
      ]);

      expect(guess[ImportField.date], 0);
      expect(guess[ImportField.amount], 1);
      expect(guess[ImportField.account], 2);
    });

    test('keeps "to account" apart from "account"', () {
      final guess = guessColumns(['Date', 'Account', 'To account', 'Amount']);

      expect(guess[ImportField.account], 1);
      expect(guess[ImportField.toAccount], 2);
    });

    test('puts "to account" first even when it comes before "account"', () {
      final guess = guessColumns(['To account', 'Account']);

      expect(guess[ImportField.toAccount], 0);
      expect(guess[ImportField.account], 1);
    });

    test('never gives one column to two fields', () {
      final guess = guessColumns(['Date Amount']);

      expect(guess.values.toSet().length, guess.length);
      expect(guess, {ImportField.date: 0});
    });

    test('finds a type column', () {
      expect(guessColumns(['Date', 'Type', 'Amount'])[ImportField.type], 1);
      expect(
        guessColumns(['Date', 'Income/Expense', 'Amount'])[ImportField.type],
        1,
      );
    });

    test('knows some Bangla headers', () {
      final guess = guessColumns(['তারিখ', 'টাকা', 'খাত', 'বিবরণ']);

      expect(guess, {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.category: 2,
        ImportField.note: 3,
      });
    });

    test('leaves out fields it cannot find', () {
      expect(guessColumns(['Foo', 'Bar']), isEmpty);
      expect(guessColumns([]), isEmpty);
    });

    test('a name that is not clear is not guessed', () {
      final guess = guessColumns(['Ref', 'Col2', 'Col3']);

      expect(guess, isEmpty);
    });
  });

  group('parseTypeText', () {
    test('reads the words for each type', () {
      expect(parseTypeText('income'), TransactionType.income);
      expect(parseTypeText('Credit'), TransactionType.income);
      expect(parseTypeText(' IN '), TransactionType.income);
      expect(parseTypeText('জমা'), TransactionType.income);
      expect(parseTypeText('expense'), TransactionType.expense);
      expect(parseTypeText('Debit'), TransactionType.expense);
      expect(parseTypeText('out'), TransactionType.expense);
      expect(parseTypeText('খরচ'), TransactionType.expense);
      expect(parseTypeText('Transfer'), TransactionType.transfer);
    });

    test('is null for anything else', () {
      expect(parseTypeText(''), isNull);
      expect(parseTypeText('maybe'), isNull);
      expect(parseTypeText('food'), isNull);
    });
  });

  group('ImportMapping', () {
    test('knows the column of a field', () {
      final mapping = ImportMapping(
        columns: {ImportField.date: 2},
        dateFormat: _anyFormat,
        typeSource: TypeSource.allExpense,
      );

      expect(mapping.columnOf(ImportField.date), 2);
      expect(mapping.columnOf(ImportField.note), isNull);
    });

    test('copyWith changes only what it is given', () {
      final mapping = ImportMapping(
        columns: {ImportField.date: 0},
        dateFormat: _anyFormat,
        typeSource: TypeSource.allExpense,
        defaultAccountId: 7,
      );

      final changed = mapping.copyWith(typeSource: TypeSource.amountSign);
      expect(changed.typeSource, TypeSource.amountSign);
      expect(changed.defaultAccountId, 7);
      expect(changed.columns, mapping.columns);
    });

    test('copyWith can clear the default account', () {
      final mapping = ImportMapping(
        columns: const {},
        dateFormat: _anyFormat,
        typeSource: TypeSource.allExpense,
        defaultAccountId: 7,
      );

      expect(
        mapping.copyWith(defaultAccountId: () => null).defaultAccountId,
        isNull,
      );
    });
  });

  group('suggestMapping', () {
    CsvTable table(String csv) => parseCsvTable(csv);

    test('maps the columns, finds the date order and uses the type column', () {
      final mapping = suggestMapping(
        table(
          'Date,Amount,Type,Category,Account\n25/12/2026,100,expense,Food,Cash',
        ),
        hasHeader: true,
      );

      expect(mapping.columns, {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.type: 2,
        ImportField.category: 3,
        ImportField.account: 4,
      });
      expect(mapping.dateFormat, SheetDateFormat.dayMonthYear);
      expect(mapping.typeSource, TypeSource.column);
    });

    test('finds a year-first date order', () {
      final mapping = suggestMapping(
        table('Date,Amount\n2026-10-11,100'),
        hasHeader: true,
      );

      expect(mapping.dateFormat, SheetDateFormat.yearMonthDay);
    });

    test('finds month first when the dates need it', () {
      final mapping = suggestMapping(
        table('Date,Amount\n12/25/2026,100\n10/11/2026,5'),
        hasHeader: true,
      );

      expect(mapping.dateFormat, SheetDateFormat.monthDayYear);
    });

    test('takes the type from the sign when some amounts are negative', () {
      final mapping = suggestMapping(
        table('Date,Amount\n11/10/2026,-100\n12/10/2026,500'),
        hasHeader: true,
      );

      expect(mapping.typeSource, TypeSource.amountSign);
    });

    test('treats everything as expenses when there is no type and no negative amount', () {
      final mapping = suggestMapping(
        table('Date,Amount\n11/10/2026,100'),
        hasHeader: true,
      );

      expect(mapping.typeSource, TypeSource.allExpense);
    });

    test('without a header row nothing is guessed', () {
      final mapping = suggestMapping(
        parseCsvTable('11/10/2026,100', hasHeader: false),
        hasHeader: false,
      );

      expect(mapping.columns, isEmpty);
      expect(mapping.typeSource, TypeSource.allExpense);
    });

    test('keeps the default account it is given', () {
      final mapping = suggestMapping(
        table('Date,Amount\n11/10/2026,1'),
        hasHeader: true,
        defaultAccountId: 4,
      );

      expect(mapping.defaultAccountId, 4);
    });
  });

  group('mappingProblem', () {
    ImportMapping mapping({
      Map<ImportField, int>? columns,
      TypeSource typeSource = TypeSource.allExpense,
      int? defaultAccountId = 1,
    }) => ImportMapping(
      columns: columns ?? {ImportField.date: 0, ImportField.amount: 1},
      dateFormat: _anyFormat,
      typeSource: typeSource,
      defaultAccountId: defaultAccountId,
    );

    test('is null for a complete mapping', () {
      expect(mappingProblem(mapping()), isNull);
    });

    test('asks for the date, then the amount', () {
      expect(
        mappingProblem(mapping(columns: {ImportField.amount: 1})),
        contains('date'),
      );
      expect(
        mappingProblem(mapping(columns: {ImportField.date: 0})),
        contains('amount'),
      );
    });

    test('asks for a type column when the type is to come from one', () {
      expect(
        mappingProblem(mapping(typeSource: TypeSource.column)),
        contains('type'),
      );
      expect(
        mappingProblem(
          mapping(
            typeSource: TypeSource.column,
            columns: {
              ImportField.date: 0,
              ImportField.amount: 1,
              ImportField.type: 2,
            },
          ),
        ),
        isNull,
      );
    });

    test(
      'asks for an account when there is no account column and no default',
      () {
        expect(
          mappingProblem(mapping(defaultAccountId: null)),
          contains('account'),
        );
        expect(
          mappingProblem(
            mapping(
              defaultAccountId: null,
              columns: {
                ImportField.date: 0,
                ImportField.amount: 1,
                ImportField.account: 2,
              },
            ),
          ),
          isNull,
        );
      },
    );
  });
}

const _anyFormat = SheetDateFormat.dayMonthYear;
