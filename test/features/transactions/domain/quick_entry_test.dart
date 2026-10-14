import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/quick_entry.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

Account account(int id, String name, {bool archived = false}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  openingBalance: 0,
  includeInTotal: true,
  isArchived: archived,
);

Category category(
  int id,
  String name, {
  int? parent,
  CategoryType type = CategoryType.expense,
}) => Category(
  id: id,
  name: name,
  type: type,
  parentId: parent,
  icon: 'category',
  color: 0xFF9E9E9E,
  isArchived: false,
  sortOrder: id,
);

final options = AddTransactionOptions(
  accounts: [
    account(1, 'Cash'),
    account(2, 'bKash'),
    account(3, 'Old', archived: true),
  ],
  defaultAccountId: 1,
  expenseCategories: [
    category(10, 'Food'),
    category(11, 'Kacha bazar', parent: 10),
    category(12, 'Fish', parent: 11),
    category(13, 'Transport'),
    category(14, 'Bus & rickshaw', parent: 13),
  ],
  incomeCategories: [
    category(20, 'Salary', type: CategoryType.income),
    category(21, 'Business', type: CategoryType.income),
  ],
);

void main() {
  group('the amount', () {
    test('is the last number', () {
      expect(parseQuickEntry('rickshaw 50', options).amount, 5000);
      expect(parseQuickEntry('2 kg chal 300', options).amount, 30000);
    });

    test('understands k, hajar and lakh', () {
      expect(parseQuickEntry('rent 2k', options).amount, 200000);
      expect(parseQuickEntry('rent 1.5k', options).amount, 150000);
      expect(parseQuickEntry('rent 3 hajar', options).amount, 300000);
      expect(parseQuickEntry('car 2 lakh', options).amount, 20000000);
    });

    test('ignores commas, the taka sign and tk', () {
      expect(parseQuickEntry('bazar ৳1,250', options).amount, 125000);
      expect(parseQuickEntry('bazar 450 tk', options).amount, 45000);
      expect(parseQuickEntry('bazar 450টাকা', options).amount, 45000);
    });

    test('reads Bengali digits', () {
      expect(parseQuickEntry('রিকশা ৫০', options).amount, 5000);
    });

    test('is null when there is no number', () {
      expect(parseQuickEntry('rickshaw', options).amount, isNull);
    });
  });

  group('the type', () {
    test('is an expense unless the line says income', () {
      expect(
        parseQuickEntry('bazar 450', options).type,
        TransactionType.expense,
      );
      expect(
        parseQuickEntry('+bonus 5000', options).type,
        TransactionType.income,
      );
      expect(
        parseQuickEntry('salary 30k', options).type,
        TransactionType.income,
      );
    });

    test('leaves the plus sign out of the note', () {
      expect(parseQuickEntry('+ tuition 4000', options).note, 'Tuition');
    });
  });

  group('the account', () {
    test('is the one named in the line, case does not matter', () {
      final entry = parseQuickEntry('bazar 450 BKASH', options);
      expect(entry.account?.id, 2);
      expect(entry.note, 'Bazar');
    });

    test('is null when none is named, and archived ones are skipped', () {
      expect(parseQuickEntry('bazar 450', options).account, isNull);
      expect(parseQuickEntry('old 450', options).account, isNull);
    });
  });

  group('the category', () {
    test('is the one with that name', () {
      expect(parseQuickEntry('fish 300', options).category?.id, 12);
      expect(parseQuickEntry('transport 50', options).category?.id, 13);
    });

    test('is the one with the word in its name', () {
      expect(parseQuickEntry('rickshaw 50', options).category?.id, 14);
      expect(parseQuickEntry('bazar 450', options).category?.id, 11);
    });

    test('comes from everyday words', () {
      expect(parseQuickEntry('ilish 900', options).category?.id, 12);
    });

    test('follows the type', () {
      expect(parseQuickEntry('salary 30k', options).category?.id, 20);
    });

    test('is null when nothing fits', () {
      expect(parseQuickEntry('zzzz 10', options).category, isNull);
    });
  });

  test('an empty or blank line says nothing', () {
    expect(parseQuickEntry('', options).isEmpty, isTrue);
    expect(parseQuickEntry('   ', options).isEmpty, isTrue);
  });
}
