import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// A fresh in-memory database. Empty unless [seedDefaults] is true.
///
/// Every call is its own database, so tests that use two at once (a backup
/// of one restored into another) are fine: drift's warning about opening the
/// database class twice is for two databases on the same file.
AppDatabase createTestDatabase({bool seedDefaults = false}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase.withExecutor(
    NativeDatabase.memory(),
    seedDefaults: seedDefaults,
  );
}

Future<int> insertTestAccount(
  AppDatabase db, {
  String name = 'Cash',
  AccountType type = AccountType.cash,
}) => db.accountsDao.insertAccount(
  AccountsCompanion.insert(name: name, type: type),
);

Future<int> insertTestCategory(
  AppDatabase db, {
  String name = 'Food',
  CategoryType type = CategoryType.expense,
  int? parentId,
}) => db.categoriesDao.insertCategory(
  CategoriesCompanion.insert(name: name, type: type, parentId: Value(parentId)),
);

/// Matches a SQLite constraint failure, e.g. `throwsConstraint('CHECK')`.
Matcher throwsConstraint(String kind) => throwsA(
  predicate<Object>(
    (error) => error.toString().contains('$kind constraint failed'),
    'is a $kind constraint failure',
  ),
);

/// Matches a [ValidationException], optionally with [messagePart] in its text.
Matcher throwsValidation([String? messagePart]) => throwsA(
  isA<ValidationException>().having(
    (error) => error.message,
    'message',
    messagePart == null ? isNotEmpty : contains(messagePart),
  ),
);
