import 'package:drift/drift.dart' show Value;
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import 'test_database.dart';

/// Two accounts and three categories, enough for most screen tests.
class Basics {
  const Basics({
    required this.cash,
    required this.bkash,
    required this.food,
    required this.transport,
    required this.salary,
  });

  final int cash;
  final int bkash;
  final int food;
  final int transport;
  final int salary;
}

Future<Basics> seedBasics(AppDatabase db) async => Basics(
  cash: await insertTestAccount(db, name: 'Cash'),
  bkash: await insertTestAccount(db, name: 'bKash'),
  food: await insertTestCategory(db, name: 'Food'),
  transport: await insertTestCategory(db, name: 'Transport'),
  salary: await insertTestCategory(
    db,
    name: 'Salary',
    type: CategoryType.income,
  ),
);

/// Inserts a transaction straight into the database.
Future<int> addTransaction(
  AppDatabase db, {
  required TransactionType type,
  required int amount,
  required int accountId,
  required DateTime date,
  int? categoryId,
  int? toAccountId,
  String note = '',
}) => db.transactionsDao.insertTransaction(
  TransactionsCompanion.insert(
    type: type,
    amount: amount,
    accountId: accountId,
    categoryId: Value(categoryId),
    toAccountId: Value(toAccountId),
    date: date,
    note: Value(note),
  ),
);
