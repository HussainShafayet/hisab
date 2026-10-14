import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/data/account_mapper.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/data/transactions_dao.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/category_usage.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
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

  /// Every transaction with tag [tagId], newest first.
  Stream<List<TransactionItem>> watchByTag(int tagId) => _db.transactionsDao
      .watchByTagWithDetails(tagId)
      .map((rows) => rows.map(toTransactionItem).toList());

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
        throw ValidationException(tr('The fee cannot be negative.'));
      }
      if (fee > 0 && input.type != TransactionType.transfer) {
        throw ValidationException(tr('Only a transfer can have a fee.'));
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
        throw ValidationException(tr('Transaction not found.'));
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
          usdAmount: Value(input.usdAmount),
          tagId: Value(input.tagId),
          feeling: Value(_feelingOf(input)),
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
        usdAmount: Value(item.usdAmount),
        tagId: Value(item.tagId),
        feeling: Value(item.feeling),
      ),
    );
  }

  /// What the add/edit form can choose from. When [editing] is given, its
  /// account and category are included even if they have been archived.
  /// [preferredAccountId] is the account chosen in Settings for new
  /// transactions.
  Future<AddTransactionOptions> loadAddOptions({
    required DateTime now,
    TransactionItem? editing,
    int? preferredAccountId,
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

    // The picker shows the categories as a tree, and the ones used most in a
    // row of their own.
    final since = now.subtract(_usageWindow);
    Future<({List<Category> tree, List<int> frequent})> categoriesFor(
      TransactionType type,
    ) async {
      final ofType = categories.where((c) => c.type == type.categoryType);
      final tree = flattenCategoryTree(buildCategoryTree(ofType));
      final usage = await _db.transactionsDao.categoryUsage(type, since: since);
      final frequent = [
        for (final category in sortCategoriesByUsage(tree, usage))
          if (usage.containsKey(category.id)) category.id,
      ].take(maxFrequentCategories).toList();
      return (tree: tree, frequent: frequent);
    }

    // The account chosen in Settings, else the one used last, else the first.
    // An account that is gone or archived is skipped.
    final lastUsed = await _db.transactionsDao.lastUsedAccountId();
    bool usable(int? id) =>
        id != null && accounts.any((a) => a.id == id && !a.isArchived);
    final defaultAccountId = usable(preferredAccountId)
        ? preferredAccountId
        : usable(lastUsed)
        ? lastUsed
        : accounts.where((a) => !a.isArchived).firstOrNull?.id;

    final expense = await categoriesFor(TransactionType.expense);
    final income = await categoriesFor(TransactionType.income);
    return AddTransactionOptions(
      accounts: accounts,
      defaultAccountId: defaultAccountId,
      expenseCategories: expense.tree,
      incomeCategories: income.tree,
      frequentExpenseIds: expense.frequent,
      frequentIncomeIds: income.frequent,
    );
  }

  Future<void> _validate(
    TransactionInput input, {
    TransactionRow? existing,
  }) async {
    if (input.amount <= 0) {
      throw ValidationException(tr('The amount must be above zero.'));
    }
    if (input.note.trim().length > maxNoteLength) {
      throw ValidationException(
        tr('The note must be {max} characters or fewer.', {
          'max': maxNoteLength,
        }),
      );
    }

    await _requireUsableAccount(
      input.accountId,
      unchanged: existing?.accountId,
    );
    await _validateDollars(input);
    await _validateTag(input);

    if (input.type == TransactionType.transfer) {
      final toId = input.toAccountId;
      if (toId == null) {
        throw ValidationException(tr('Choose the account the money goes to.'));
      }
      if (toId == input.accountId) {
        throw ValidationException(tr('Choose two different accounts.'));
      }
      if (input.categoryId != null) {
        throw ValidationException(tr('A transfer has no category.'));
      }
      await _requireUsableAccount(toId, unchanged: existing?.toAccountId);
      return;
    }

    if (input.toAccountId != null) {
      throw ValidationException(tr('Only a transfer has a second account.'));
    }
    final categoryId = input.categoryId;
    if (categoryId == null) {
      throw ValidationException(tr('Choose a category.'));
    }
    final category = await _db.categoriesDao.getById(categoryId);
    if (category == null) {
      throw ValidationException(tr('Category not found.'));
    }
    if (category.type != input.type.categoryType) {
      final args = {'name': category.name};
      throw ValidationException(
        input.type == TransactionType.income
            ? tr('The category "{name}" is not an income category.', args)
            : tr('The category "{name}" is not an expense category.', args),
      );
    }
    if (category.isArchived && category.id != existing?.categoryId) {
      throw ValidationException(
        tr('The category "{name}" is archived.', {'name': category.name}),
      );
    }
  }

  /// A tag has to exist, and only an income or an expense can have one.
  Future<void> _validateTag(TransactionInput input) async {
    final tagId = input.tagId;
    if (tagId == null) return;
    if (input.type == TransactionType.transfer) {
      throw ValidationException(tr('A transfer cannot have a tag.'));
    }
    if (await _db.tagsDao.getById(tagId) == null) {
      throw ValidationException(tr('Tag not found.'));
    }
  }

  /// Dollars only make sense on a credit card: the card that is spent on,
  /// refunded, or paid into.
  Future<void> _validateDollars(TransactionInput input) async {
    final usd = input.usdAmount;
    if (usd == null) return;
    if (usd <= 0) {
      throw ValidationException(tr('The dollar amount must be above zero.'));
    }
    final cardId = input.type == TransactionType.transfer
        ? input.toAccountId
        : input.accountId;
    final card = cardId == null ? null : await _db.accountsDao.getById(cardId);
    if (card == null || card.type != AccountType.creditCard) {
      throw ValidationException(
        tr('A dollar amount can only be used with a credit card.'),
      );
    }
  }

  /// [unchanged] is the account the transaction already uses: an archived
  /// account is fine if it is still that one.
  Future<void> _requireUsableAccount(int id, {int? unchanged}) async {
    final account = await _db.accountsDao.getById(id);
    if (account == null) throw ValidationException(tr('Account not found.'));
    if (account.isArchived && id != unchanged) {
      throw ValidationException(
        tr('The account "{name}" is archived.', {'name': account.name}),
      );
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
        usdAmount: Value(input.usdAmount),
        tagId: Value(input.tagId),
        feeling: Value(_feelingOf(input)),
      );

  /// Only an expense keeps how it felt.
  Feeling? _feelingOf(TransactionInput input) =>
      input.type == TransactionType.expense ? input.feeling : null;
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
    usdAmount: transaction.usdAmount,
    tagId: transaction.tagId,
    tagName: row.tag?.name,
    feeling: transaction.feeling,
  );
}
