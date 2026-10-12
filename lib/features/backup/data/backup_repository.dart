import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:intl/intl.dart';

/// Saving everything to a file and bringing it back, and exporting the
/// transactions as a spreadsheet.
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  /// All accounts (archived ones too), categories, transactions and budgets.
  Future<BackupData> buildBackup(DateTime now) async {
    final accounts = await _db.accountsDao.getAll(includeArchived: true);
    final categories = await _db.categoriesDao.getAll(includeArchived: true);
    final transactions = await _db.transactionsDao.getAll();
    final budgets = await _db.budgetsDao.getAll();
    return BackupData(
      exportedAt: now.toUtc(),
      accounts: [
        for (final a in accounts)
          BackupAccount(
            id: a.id,
            name: a.name,
            type: a.type,
            openingBalance: a.openingBalance,
            includeInTotal: a.includeInTotal,
            isArchived: a.isArchived,
            createdAt: a.createdAt.toUtc(),
          ),
      ],
      categories: [
        for (final c in categories)
          BackupCategory(
            id: c.id,
            name: c.name,
            type: c.type,
            parentId: c.parentId,
            icon: c.icon,
            color: c.color,
            isArchived: c.isArchived,
            sortOrder: c.sortOrder,
          ),
      ],
      transactions: [
        for (final t in transactions)
          BackupTransaction(
            id: t.id,
            type: t.type,
            amount: t.amount,
            accountId: t.accountId,
            toAccountId: t.toAccountId,
            categoryId: t.categoryId,
            date: t.date.toUtc(),
            note: t.note,
            isAdjustment: t.isAdjustment,
            createdAt: t.createdAt.toUtc(),
            updatedAt: t.updatedAt.toUtc(),
          ),
      ],
      budgets: [
        for (final b in budgets)
          BackupBudget(
            id: b.id,
            month: b.month,
            categoryId: b.categoryId,
            amount: b.amount,
          ),
      ],
    );
  }

  /// Replaces everything in the app with [data]. All or nothing: if anything
  /// goes wrong the app keeps what it had.
  Future<void> restore(BackupData data) async {
    try {
      await _db.transaction(() async {
        await _deleteEverything();
        await _db.batch((batch) {
          batch.insertAll(_db.accounts, [
            for (final a in data.accounts)
              AccountsCompanion.insert(
                id: Value(a.id),
                name: a.name,
                type: a.type,
                openingBalance: Value(a.openingBalance),
                includeInTotal: Value(a.includeInTotal),
                isArchived: Value(a.isArchived),
                createdAt: Value(a.createdAt),
              ),
          ]);
          // Parents first: a sub-category points at its parent. (The sort is
          // stable, so categories keep their order within a level.)
          batch.insertAll(_db.categories, [
            for (final c in data.categoriesParentsFirst)
              CategoriesCompanion.insert(
                id: Value(c.id),
                name: c.name,
                type: c.type,
                parentId: Value(c.parentId),
                icon: Value(c.icon),
                color: Value(c.color),
                isArchived: Value(c.isArchived),
                sortOrder: Value(c.sortOrder),
              ),
          ]);
          batch.insertAll(_db.transactions, [
            for (final t in data.transactions)
              TransactionsCompanion.insert(
                id: Value(t.id),
                type: t.type,
                amount: t.amount,
                accountId: t.accountId,
                toAccountId: Value(t.toAccountId),
                categoryId: Value(t.categoryId),
                date: t.date,
                note: Value(t.note),
                isAdjustment: Value(t.isAdjustment),
                createdAt: Value(t.createdAt),
                updatedAt: Value(t.updatedAt),
              ),
          ]);
          batch.insertAll(_db.budgets, [
            for (final b in data.budgets)
              BudgetsCompanion.insert(
                id: Value(b.id),
                month: b.month,
                amount: b.amount,
                categoryId: Value(b.categoryId),
              ),
          ]);
        });
      });
    } on ValidationException {
      rethrow;
    } on Object catch (error) {
      throw ValidationException(
        'The backup could not be restored, and nothing was changed. $error',
      );
    }
  }

  /// Rows that others point at go last: transactions and budgets first, then
  /// categories from the innermost out, then accounts.
  Future<void> _deleteEverything() async {
    await _db.delete(_db.budgets).go();
    await _db.delete(_db.transactions).go();
    // A category that has others inside it cannot go before them, so remove
    // the ones nothing is inside, over and over, until none are left. Each
    // round takes one level off the bottom of the tree.
    var removed = 1;
    while (removed > 0) {
      removed = await _db.customUpdate(
        'DELETE FROM categories WHERE id NOT IN '
        '(SELECT parent_id FROM categories WHERE parent_id IS NOT NULL)',
        updates: {_db.categories},
        updateKind: UpdateKind.delete,
      );
    }
    await _db.delete(_db.accounts).go();
  }

  /// Every transaction as a spreadsheet, oldest first:
  /// `Date, Type, Amount, Account, To account, Category, Note, Correction`.
  /// The category of a sub-category is written with its whole path, like
  /// `Food > Restaurant > Dinner`. Amounts are
  /// plain taka (`1234.50`), the type is income, expense or transfer, and
  /// "Correction" says `yes` for a balance adjustment. The columns have the
  /// names the CSV import looks for, so the file can be imported again.
  Future<String> exportTransactionsCsv() async {
    final categories = await _db.categoriesDao.getAll(includeArchived: true);
    final byId = {for (final c in categories) c.id: c.toDomain()};
    final rows = await _db.transactionsDao.getAllWithDetails();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    String categoryPath(CategoryRow? category) {
      final domain = category == null ? null : byId[category.id];
      return domain == null
          ? ''
          : categoryPathLabel(domain, byId, separator: ' > ');
    }

    final table = <List<String>>[
      [
        'Date',
        'Type',
        'Amount',
        'Account',
        'To account',
        'Category',
        'Note',
        'Correction',
      ],
      for (final row in rows)
        [
          dateFormat.format(row.transaction.date.toLocal()),
          row.transaction.type.name,
          poishaToFixed(row.transaction.amount),
          row.account.name,
          row.transaction.type == TransactionType.transfer
              ? (row.toAccount?.name ?? '')
              : '',
          categoryPath(row.category),
          row.transaction.note,
          row.transaction.isAdjustment ? 'yes' : '',
        ],
    ];
    // A byte order mark lets Excel and Sheets read Bangla text correctly.
    return Csv(addBom: true).encode(table);
  }
}
