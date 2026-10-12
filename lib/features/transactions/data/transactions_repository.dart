import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/data/account_mapper.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/data/transactions_dao.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/category_usage.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Everything the UI needs to know about transactions: reading them with the
/// names to show, and adding, changing, deleting and restoring them with the
/// rules checked in one place.
class TransactionsRepository {
  TransactionsRepository(this._db);

  final AppDatabase _db;

  static const maxNoteLength = 500;

  /// Chips are ordered by how much a category was used in this many days.
  static const _usageWindow = Duration(days: 90);

  /// Transactions with `start <= date < end`, newest first.
  Stream<List<TransactionItem>> watchBetween(DateTime start, DateTime end) {
    return _db.transactionsDao
        .watchBetweenWithDetails(start, end)
        .map((rows) => rows.map(toTransactionItem).toList());
  }

  Future<TransactionItem?> getTransaction(int id) async {
    final row = await _db.transactionsDao.getWithDetails(id);
    return row == null ? null : toTransactionItem(row);
  }

  /// Saves a new transaction and returns its id.
  ///
  /// For a transfer, a [fee] above zero is saved as a separate expense on the
  /// account the money leaves, in the "Fees & charges" category. Both rows
  /// are saved together or not at all.
  Future<int> addTransaction(TransactionInput input, {int fee = 0}) {
    return _db.transaction(() async {
      if (fee < 0) {
        throw const ValidationException('The fee cannot be negative.');
      }
      if (fee > 0 && input.type != TransactionType.transfer) {
        throw const ValidationException('Only a transfer can have a fee.');
      }
      await _validate(input);
      final id = await _db.transactionsDao.insertTransaction(
        _toCompanion(input),
      );
      if (fee > 0) {
        final feeCategoryId = await _db.categoriesDao.findOrCreateTopLevel(
          transferFeeCategoryName,
          CategoryType.expense,
          icon: 'account_balance',
          color: 0xFF78909C,
        );
        await _db.transactionsDao.insertTransaction(
          _toCompanion(
            TransactionInput(
              type: TransactionType.expense,
              amount: fee,
              accountId: input.accountId,
              categoryId: feeCategoryId,
              date: input.date,
              note: transferFeeNote,
            ),
          ),
        );
      }
      return id;
    });
  }

  /// Replaces what was saved for transaction [id]. The type may change, for
  /// example from expense to transfer. The account and category it already
  /// uses may be archived; any other account or category must not be.
  Future<void> updateTransaction(int id, TransactionInput input) {
    return _db.transaction(() async {
      final existing = await _db.transactionsDao.getById(id);
      if (existing == null) {
        throw const ValidationException('Transaction not found.');
      }
      await _validate(input, existing: existing);
      await _db.transactionsDao.updateTransaction(
        existing.copyWith(
          type: input.type,
          amount: input.amount,
          accountId: input.accountId,
          toAccountId: Value(input.toAccountId),
          categoryId: Value(input.categoryId),
          date: input.date,
          note: input.note.trim(),
        ),
      );
    });
  }

  /// Deletes transaction [id] and returns what was deleted, so it can be
  /// passed to [restoreTransaction] for "Undo". Null if it did not exist.
  Future<TransactionItem?> deleteTransaction(int id) async {
    final item = await getTransaction(id);
    if (item == null) return null;
    await _db.transactionsDao.deleteTransaction(id);
    return item;
  }

  /// Puts a deleted transaction back with the same id and creation time.
  Future<void> restoreTransaction(TransactionItem item) async {
    await _db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        id: Value(item.id),
        type: item.type,
        amount: item.amount,
        accountId: item.accountId,
        toAccountId: Value(item.toAccountId),
        categoryId: Value(item.categoryId),
        date: item.date,
        note: Value(item.note),
        createdAt: Value(item.createdAt),
        isAdjustment: Value(item.isAdjustment),
      ),
    );
  }

  /// What the add/edit form can choose from. When [editing] is given, its
  /// account and category are included even if they have been archived.
  Future<AddTransactionOptions> loadAddOptions({
    required DateTime now,
    TransactionItem? editing,
  }) async {
    final accountRows = await _db.accountsDao.getAll();
    final accounts = [for (final row in accountRows) row.toDomain()];
    for (final id in [editing?.accountId, editing?.toAccountId]) {
      if (id != null && !accounts.any((a) => a.id == id)) {
        final row = await _db.accountsDao.getById(id);
        if (row != null) accounts.add(row.toDomain());
      }
    }

    final categoryRows = await _db.categoriesDao.getAll();
    final categories = [for (final row in categoryRows) row.toDomain()];
    final editedCategoryId = editing?.categoryId;
    if (editedCategoryId != null &&
        !categories.any((c) => c.id == editedCategoryId)) {
      final row = await _db.categoriesDao.getById(editedCategoryId);
      if (row != null) categories.add(row.toDomain());
    }

    final since = now.subtract(_usageWindow);
    Future<List<Category>> chipsFor(TransactionType type) async {
      final ofType = categories.where((c) => c.type == type.categoryType);
      final usage = await _db.transactionsDao.categoryUsage(type, since: since);
      return sortCategoriesByUsage(
        flattenCategoryTree(buildCategoryTree(ofType)),
        usage,
      );
    }

    final lastUsed = await _db.transactionsDao.lastUsedAccountId();
    final defaultAccountId =
        accounts.any((a) => a.id == lastUsed && !a.isArchived)
        ? lastUsed
        : accounts.where((a) => !a.isArchived).firstOrNull?.id;

    return AddTransactionOptions(
      accounts: accounts,
      defaultAccountId: defaultAccountId,
      expenseCategories: await chipsFor(TransactionType.expense),
      incomeCategories: await chipsFor(TransactionType.income),
    );
  }

  Future<void> _validate(
    TransactionInput input, {
    TransactionRow? existing,
  }) async {
    if (input.amount <= 0) {
      throw const ValidationException('The amount must be above zero.');
    }
    if (input.note.trim().length > maxNoteLength) {
      throw const ValidationException(
        'The note must be $maxNoteLength characters or fewer.',
      );
    }

    await _requireUsableAccount(
      input.accountId,
      unchanged: existing?.accountId,
    );

    if (input.type == TransactionType.transfer) {
      final toId = input.toAccountId;
      if (toId == null) {
        throw const ValidationException(
          'Choose the account the money goes to.',
        );
      }
      if (toId == input.accountId) {
        throw const ValidationException('Choose two different accounts.');
      }
      if (input.categoryId != null) {
        throw const ValidationException('A transfer has no category.');
      }
      await _requireUsableAccount(toId, unchanged: existing?.toAccountId);
      return;
    }

    if (input.toAccountId != null) {
      throw const ValidationException('Only a transfer has a second account.');
    }
    final categoryId = input.categoryId;
    if (categoryId == null) {
      throw const ValidationException('Choose a category.');
    }
    final category = await _db.categoriesDao.getById(categoryId);
    if (category == null) {
      throw const ValidationException('Category not found.');
    }
    if (category.type != input.type.categoryType) {
      throw ValidationException(
        'The category "${category.name}" is not an ${input.type.name} category.',
      );
    }
    if (category.isArchived && category.id != existing?.categoryId) {
      throw ValidationException('The category "${category.name}" is archived.');
    }
  }

  /// [unchanged] is the account the transaction already uses: an archived
  /// account is fine if it is still that one.
  Future<void> _requireUsableAccount(int id, {int? unchanged}) async {
    final account = await _db.accountsDao.getById(id);
    if (account == null) throw const ValidationException('Account not found.');
    if (account.isArchived && id != unchanged) {
      throw ValidationException('The account "${account.name}" is archived.');
    }
  }

  TransactionsCompanion _toCompanion(TransactionInput input) =>
      TransactionsCompanion.insert(
        type: input.type,
        amount: input.amount,
        accountId: input.accountId,
        toAccountId: Value(input.toAccountId),
        categoryId: Value(input.categoryId),
        date: input.date,
        note: Value(input.note.trim()),
      );
}

/// Turns a joined database row into a [TransactionItem].
TransactionItem toTransactionItem(TransactionWithDetails row) {
  final transaction = row.transaction;
  final category = row.category;
  return TransactionItem(
    id: transaction.id,
    type: transaction.type,
    amount: transaction.amount,
    accountId: transaction.accountId,
    accountName: row.account.name,
    toAccountId: transaction.toAccountId,
    toAccountName: row.toAccount?.name,
    categoryId: transaction.categoryId,
    categoryName: category?.name,
    categoryIcon: category?.icon,
    categoryColor: category?.color,
    categoryParentId: category?.parentId,
    date: transaction.date.toLocal(),
    note: transaction.note,
    createdAt: transaction.createdAt.toLocal(),
    isAdjustment: transaction.isAdjustment,
  );
}
