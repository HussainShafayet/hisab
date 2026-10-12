import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What an import did.
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.duplicates,
    required this.errors,
    required this.accountsCreated,
    required this.categoriesCreated,
  });

  final int imported;
  final int duplicates;
  final int errors;
  final int accountsCreated;
  final int categoriesCreated;
}

/// Reads what the app holds, to plan an import against, and carries the plan
/// out.
class CsvImportRepository {
  CsvImportRepository(this._db);

  final AppDatabase _db;

  /// The accounts, the categories and the duplicate keys of every existing
  /// transaction. Archived accounts and categories are included, so they are
  /// matched rather than created again.
  Future<ImportContext> loadContext() async {
    final accounts = await _db.accountsDao.getAll(includeArchived: true);
    final categories = await _db.categoriesDao.getAll(includeArchived: true);
    final transactions = await _db.transactionsDao.getAll();

    final counts = <String, int>{};
    for (final t in transactions) {
      final key = duplicateKey(
        date: t.date.toLocal(),
        type: t.type,
        amount: t.amount,
        accountId: t.accountId,
        toAccountId: t.toAccountId,
        note: t.note,
      );
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return ImportContext(
      accounts: [
        for (final a in accounts) ExistingAccount(id: a.id, name: a.name),
      ],
      categories: [
        for (final c in categories)
          ExistingCategory(
            id: c.id,
            name: c.name,
            type: c.type,
            parentId: c.parentId,
            isArchived: c.isArchived,
          ),
      ],
      existingKeyCounts: counts,
    );
  }

  /// Creates the accounts and categories the plan needs and saves its rows.
  /// All or nothing.
  Future<ImportResult> apply(ImportPlan plan) {
    return _db.transaction(() async {
      final accounts = await _db.accountsDao.getAll(includeArchived: true);
      final accountIds = {
        for (final a in accounts) normalizeName(a.name): a.id,
      };
      var accountsCreated = 0;
      for (final name in plan.newAccounts) {
        if (accountIds.containsKey(normalizeName(name))) continue;
        accountIds[normalizeName(name)] = await _db.accountsDao.insertAccount(
          AccountsCompanion.insert(name: name, type: guessAccountType(name)),
        );
        accountsCreated++;
      }

      final existing = await _db.categoriesDao.getAll(includeArchived: true);
      final resolver = CategoryResolver([
        for (final c in existing)
          ExistingCategory(
            id: c.id,
            name: c.name,
            type: c.type,
            parentId: c.parentId,
            isArchived: c.isArchived,
          ),
      ]);
      // The next sort order among the categories of one parent and type.
      final nextOrder = <String, int>{};
      String orderKey(CategoryType type, int? parentId) =>
          '${type.name}|$parentId';
      for (final c in existing) {
        final key = orderKey(c.type, c.parentId);
        final next = c.sortOrder + 1;
        if (next > (nextOrder[key] ?? 0)) nextOrder[key] = next;
      }
      var categoriesCreated = 0;

      Future<int> createCategory(
        String name,
        CategoryType type,
        int? parentId,
      ) async {
        final key = orderKey(type, parentId);
        final order = nextOrder[key] ?? 0;
        nextOrder[key] = order + 1;
        final id = await _db.categoriesDao.insertCategory(
          CategoriesCompanion.insert(
            name: name,
            type: type,
            parentId: Value(parentId),
            sortOrder: Value(order),
          ),
        );
        resolver.add(
          ExistingCategory(id: id, name: name, type: type, parentId: parentId),
        );
        categoriesCreated++;
        return id;
      }

      Future<int> ensureCategory(List<String> path, CategoryType type) async {
        final found = resolver.find(path, type);
        if (found != null) return found;
        int? parentId;
        if (path.length == 2) {
          parentId =
              resolver.findTopLevel(path.first, type) ??
              await createCategory(path.first, type, null);
        }
        return createCategory(path.last, type, parentId);
      }

      var imported = 0;
      for (final row in plan.toImport) {
        final parsed = row.parsed!;
        final accountId = accountIds[normalizeName(parsed.accountName)]!;
        final toAccountId = parsed.toAccountName == null
            ? null
            : accountIds[normalizeName(parsed.toAccountName!)]!;
        final categoryId = parsed.type == TransactionType.transfer
            ? null
            : await ensureCategory(
                parsed.categoryPath,
                parsed.type.categoryType!,
              );
        await _db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: parsed.type,
            amount: parsed.amount,
            accountId: accountId,
            toAccountId: Value(toAccountId),
            categoryId: Value(categoryId),
            date: parsed.date,
            note: Value(parsed.note),
          ),
        );
        imported++;
      }

      return ImportResult(
        imported: imported,
        duplicates: plan.duplicateCount,
        errors: plan.errorCount,
        accountsCreated: accountsCreated,
        categoriesCreated: categoriesCreated,
      );
    });
  }
}
