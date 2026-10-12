import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

BackupData sample() => BackupData(
  exportedAt: DateTime.utc(2026, 10, 11, 8, 30),
  accounts: [
    BackupAccount(
      id: 1,
      name: 'Cash',
      type: AccountType.cash,
      openingBalance: 150000,
      includeInTotal: true,
      isArchived: false,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    BackupAccount(
      id: 2,
      name: 'Old bank',
      type: AccountType.bank,
      openingBalance: -5000,
      includeInTotal: false,
      isArchived: true,
      createdAt: DateTime.utc(2026, 1, 2),
    ),
  ],
  categories: const [
    BackupCategory(
      id: 10,
      name: 'Food',
      type: CategoryType.expense,
      parentId: null,
      icon: 'restaurant',
      color: 0xFFEF5350,
      isArchived: false,
      sortOrder: 0,
    ),
    BackupCategory(
      id: 11,
      name: 'Groceries',
      type: CategoryType.expense,
      parentId: 10,
      icon: 'restaurant',
      color: 0xFFEF5350,
      isArchived: false,
      sortOrder: 0,
    ),
  ],
  transactions: [
    BackupTransaction(
      id: 100,
      type: TransactionType.expense,
      amount: 25050,
      accountId: 1,
      toAccountId: null,
      categoryId: 11,
      date: DateTime.utc(2026, 10, 11, 6),
      note: 'Lunch, "special"\nnew line',
      isAdjustment: false,
      createdAt: DateTime.utc(2026, 10, 11, 6, 1),
      updatedAt: DateTime.utc(2026, 10, 11, 6, 2),
    ),
    BackupTransaction(
      id: 101,
      type: TransactionType.transfer,
      amount: 100000,
      accountId: 1,
      toAccountId: 2,
      categoryId: null,
      date: DateTime.utc(2026, 10, 10),
      note: '',
      isAdjustment: false,
      createdAt: DateTime.utc(2026, 10, 10),
      updatedAt: DateTime.utc(2026, 10, 10),
    ),
  ],
  budgets: const [
    BackupBudget(id: 1, month: '2026-10', categoryId: null, amount: 3000000),
    BackupBudget(id: 2, month: '2026-10', categoryId: 10, amount: 800000),
  ],
);

Map<String, Object?> jsonOf(BackupData data) =>
    jsonDecode(data.encode()) as Map<String, Object?>;

/// Turns [change] on a copy of the sample's JSON and reads it back.
void expectDamaged(
  void Function(Map<String, Object?> json) change,
  String message,
) {
  final json = jsonOf(sample());
  change(json);
  expect(() => BackupData.fromJson(json), throwsValidation(message));
}

void main() {
  group('writing and reading', () {
    test('a backup survives being written and read back', () {
      final back = BackupData.decode(sample().encode());

      expect(back.toJson(), sample().toJson());
      expect(back.accounts.map((a) => a.name), ['Cash', 'Old bank']);
      expect(back.transactions.first.note, 'Lunch, "special"\nnew line');
      expect(back.accounts.last.openingBalance, -5000);
      expect(back.categories.last.parentId, 10);
      expect(back.budgets.first.categoryId, isNull);
    });

    test('money is whole numbers and dates are UTC text', () {
      final json = jsonOf(sample());
      final transaction =
          (json['transactions']! as List).first as Map<String, Object?>;

      expect(transaction['amount'], 25050);
      expect(transaction['date'], '2026-10-11T06:00:00.000Z');
      expect(json['formatVersion'], backupFormatVersion);
      expect(json['app'], 'hishab');
    });

    test('dates are read back as the same moment', () {
      final back = BackupData.decode(sample().encode());

      expect(
        back.transactions.first.date.isAtSameMomentAs(
          DateTime.utc(2026, 10, 11, 6),
        ),
        isTrue,
      );
      expect(back.exportedAt.isUtc, isTrue);
    });

    test('a time written with an offset is understood', () {
      final json = jsonOf(sample());
      ((json['transactions']! as List).first as Map<String, Object?>)['date'] =
          '2026-10-11T12:00:00+06:00';

      final back = BackupData.fromJson(json);

      expect(
        back.transactions.first.date.isAtSameMomentAs(
          DateTime.utc(2026, 10, 11, 6),
        ),
        isTrue,
      );
    });

    test('is_adjustment missing means false', () {
      final json = jsonOf(sample());
      for (final t in json['transactions']! as List) {
        (t as Map<String, Object?>).remove('isAdjustment');
      }

      expect(
        BackupData.fromJson(json).transactions.every((t) => !t.isAdjustment),
        isTrue,
      );
    });

    test('an empty backup is fine', () {
      final empty = BackupData(
        exportedAt: DateTime.utc(2026),
        accounts: const [],
        categories: const [],
        transactions: const [],
        budgets: const [],
      );

      final back = BackupData.decode(empty.encode());

      expect(back.accounts, isEmpty);
      expect(back.transactions, isEmpty);
    });
  });

  group('a file that is not a backup', () {
    test('text that is not JSON', () {
      expect(
        () => BackupData.decode('hello'),
        throwsValidation('not a Hishab backup'),
      );
      expect(
        () => BackupData.decode(''),
        throwsValidation('not a Hishab backup'),
      );
    });

    test('JSON from somewhere else', () {
      expect(
        () => BackupData.decode('[]'),
        throwsValidation('not a Hishab backup'),
      );
      expect(
        () => BackupData.decode('{"foo": 1}'),
        throwsValidation('not a Hishab backup'),
      );
      expect(
        () => BackupData.decode('{"app": "other", "formatVersion": 1}'),
        throwsValidation('not a Hishab backup'),
      );
    });

    test('a backup made by a newer version of the app', () {
      final json = jsonOf(sample())
        ..['formatVersion'] = backupFormatVersion + 1;

      expect(
        () => BackupData.fromJson(json),
        throwsValidation('newer version'),
      );
    });
  });

  group('a damaged backup', () {
    test('a missing list or field', () {
      expectDamaged(
        (j) => j.remove('transactions'),
        '"transactions" is missing',
      );
      expectDamaged(
        (j) => j.remove('exportedAt'),
        'no valid date "exportedAt"',
      );
      expectDamaged(
        (j) => ((j['accounts']! as List).first as Map<String, Object?>).remove(
          'name',
        ),
        'no text "name"',
      );
      expectDamaged(
        (j) => ((j['transactions']! as List).first as Map<String, Object?>)
            .remove('amount'),
        'no whole number "amount"',
      );
    });

    test('a field of the wrong kind', () {
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).first
                    as Map<String, Object?>)['amount'] =
                '25050',
        'no whole number "amount"',
      );
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).first
                    as Map<String, Object?>)['amount'] =
                250.5,
        'no whole number "amount"',
      );
      expectDamaged(
        (j) =>
            ((j['accounts']! as List).first
                    as Map<String, Object?>)['isArchived'] =
                'no',
        'no true/false',
      );
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).first
                    as Map<String, Object?>)['date'] =
                'yesterday',
        'no valid date "date"',
      );
      expectDamaged((j) => j['accounts'] = {'a': 1}, '"accounts" is missing');
      expectDamaged(
        (j) => (j['accounts']! as List).add('Cash'),
        'An account is not an object',
      );
    });

    test('an unknown type', () {
      expectDamaged(
        (j) =>
            ((j['accounts']! as List).first as Map<String, Object?>)['type'] =
                'crypto',
        'unknown "type": "crypto"',
      );
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).first
                    as Map<String, Object?>)['type'] =
                'gift',
        'unknown "type"',
      );
    });

    test('two rows with the same id', () {
      expectDamaged(
        (j) =>
            ((j['accounts']! as List).last as Map<String, Object?>)['id'] = 1,
        'two accounts have the id 1',
      );
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).last as Map<String, Object?>)['id'] =
                100,
        'two transactions have the id 100',
      );
    });

    test('a link to something that is not in the file', () {
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).first
                    as Map<String, Object?>)['accountId'] =
                99,
        'transaction 100 points to an account',
      );
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).last
                    as Map<String, Object?>)['toAccountId'] =
                99,
        'transaction 101 points to an account',
      );
      expectDamaged(
        (j) =>
            ((j['transactions']! as List).first
                    as Map<String, Object?>)['categoryId'] =
                99,
        'points to a category',
      );
      expectDamaged(
        (j) =>
            ((j['categories']! as List).last
                    as Map<String, Object?>)['parentId'] =
                99,
        'category 11 has a parent that is not',
      );
      expectDamaged(
        (j) =>
            ((j['budgets']! as List).last
                    as Map<String, Object?>)['categoryId'] =
                99,
        'budget 2 points to a category',
      );
    });

    test('categories nested too deep, or inside themselves', () {
      expectDamaged((j) {
        (j['categories']! as List).add({
          'id': 12,
          'name': 'Rice',
          'type': 'expense',
          'parentId': 11,
          'icon': 'x',
          'color': 1,
          'isArchived': false,
          'sortOrder': 0,
        });
      }, 'nested more than one level');
      expectDamaged(
        (j) =>
            ((j['categories']! as List).first
                    as Map<String, Object?>)['parentId'] =
                10,
        'nested more than one level',
      );
    });

    test('the message says the backup is damaged', () {
      expectDamaged((j) => j.remove('accounts'), 'The backup is damaged');
    });
  });
}
