import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
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
    this.batchId,
  });

  final int imported;
  final int duplicates;
  final int errors;
  final int accountsCreated;
  final int categoriesCreated;

  /// The import as it is kept for undoing it; null when nothing was imported.
  final int? batchId;
}

/// A CSV import that can still be undone.
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.fileName,
    required this.transactionCount,
    required this.createdAt,
  });

  final int id;
  final String fileName;
  final int transactionCount;
  final DateTime createdAt;
}

/// What undoing an import took away.
class UndoResult {
  const UndoResult({
    required this.transactions,
    required this.categoriesHidden,
    required this.accountsHidden,
  });

  final int transactions;

  /// Categories the import had made that nothing uses any more.
  final int categoriesHidden;

  /// Accounts the import had made that have no transactions any more.
  final int accountsHidden;
}

/// Where the mappings of earlier files are kept, in the app settings.
const importMappingsKey = 'import_mappings';

/// How many file layouts are remembered.
const maxSavedMappings = 8;

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
        for (final a in accounts)
          ExistingAccount(
            id: a.id,
            name: a.name,
            includeInTotal: a.includeInTotal,
          ),
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
  Future<ImportResult> apply(ImportPlan plan, {String fileName = ''}) {
    return _db.transaction(() async {
      final batchId = await _db
          .into(_db.importBatches)
          .insert(
            ImportBatchesCompanion.insert(
              fileName: fileName,
              transactionCount: 0,
            ),
          );
      final createdAccountIds = <int>[];
      final createdCategoryIds = <int>[];

      final accounts = await _db.accountsDao.getAll(includeArchived: true);
      final accountIds = {
        for (final a in accounts) normalizeName(a.name): a.id,
      };
      var accountsCreated = 0;
      for (final name in plan.newAccounts) {
        if (accountIds.containsKey(normalizeName(name))) continue;
        final id = await _db.accountsDao.insertAccount(
          AccountsCompanion.insert(name: name, type: guessAccountType(name)),
        );
        accountIds[normalizeName(name)] = id;
        createdAccountIds.add(id);
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
        createdCategoryIds.add(id);
        categoriesCreated++;
        return id;
      }

      final existingIds = {for (final c in existing) c.id};

      Future<int> ensureCategory(List<String> path, CategoryType type) async {
        // A category the person matched with one of the app's by hand.
        final chosen = plan.categoryMap[categoryKey(type, path)];
        if (chosen != null && existingIds.contains(chosen)) return chosen;
        final found = resolver.find(path, type);
        if (found != null) return found;
        // Walk down the path, making the levels that are missing.
        int? parentId;
        for (final name in path) {
          parentId =
              (parentId == null
                  ? resolver.findTopLevel(name, type)
                  : resolver.findChild(parentId, name)) ??
              await createCategory(name, type, parentId);
        }
        return parentId!;
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
            importBatchId: Value(batchId),
          ),
        );
        imported++;
      }

      // Kept so that the import can be undone, unless it added nothing.
      if (imported == 0) {
        await (_db.delete(
          _db.importBatches,
        )..where((b) => b.id.equals(batchId))).go();
      } else {
        await (_db.update(
          _db.importBatches,
        )..where((b) => b.id.equals(batchId))).write(
          ImportBatchesCompanion(
            transactionCount: Value(imported),
            createdAccountIds: Value(createdAccountIds.join(',')),
            createdCategoryIds: Value(createdCategoryIds.join(',')),
          ),
        );
      }

      return ImportResult(
        imported: imported,
        duplicates: plan.duplicateCount,
        errors: plan.errorCount,
        accountsCreated: accountsCreated,
        categoriesCreated: categoriesCreated,
        batchId: imported == 0 ? null : batchId,
      );
    });
  }

  /// The latest import that has not been undone, or null.
  Stream<ImportBatch?> watchLastBatch() =>
      (_db.select(_db.importBatches)
            ..orderBy([(b) => OrderingTerm.desc(b.id)])
            ..limit(1))
          .watchSingleOrNull()
          .map(
            (row) => row == null
                ? null
                : ImportBatch(
                    id: row.id,
                    fileName: row.fileName,
                    transactionCount: row.transactionCount,
                    createdAt: row.createdAt,
                  ),
          );

  List<int> _ids(String joined) => [
    for (final part in joined.split(','))
      if (int.tryParse(part) != null) int.parse(part),
  ];

  Future<bool> _isUsed(String table, String column, int id) async {
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM $table WHERE $column = ? LIMIT 1',
          variables: [Variable.withInt(id)],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Takes back an import: removes the transactions it added, and hides the
  /// categories and accounts it made that nothing uses any more (they are
  /// hidden, not deleted: the app never deletes an account). All or nothing.
  Future<UndoResult> undo(int batchId) {
    return _db.transaction(() async {
      final batch = await (_db.select(
        _db.importBatches,
      )..where((b) => b.id.equals(batchId))).getSingleOrNull();
      if (batch == null) {
        throw ValidationException(tr('This import was already undone.'));
      }

      final removed = await (_db.delete(
        _db.transactions,
      )..where((t) => t.importBatchId.equals(batchId))).go();

      // A category made inside another one has a later id, so the innermost
      // come first and the ones around them may then be free too.
      var categoriesHidden = 0;
      final categoryIds = _ids(batch.createdCategoryIds)
        ..sort((a, b) => b.compareTo(a));
      for (final id in categoryIds) {
        final inUse =
            await _isUsed('transactions', 'category_id', id) ||
            await _isUsed('budgets', 'category_id', id) ||
            await _isUsed('recurring_rules', 'category_id', id) ||
            await _isUsed('challenges', 'category_id', id) ||
            await _hasActiveChild(id);
        if (inUse) continue;
        await _db.categoriesDao.setArchived(id, archived: true);
        categoriesHidden++;
      }

      var accountsHidden = 0;
      for (final id in _ids(batch.createdAccountIds)) {
        final inUse =
            await _isUsed('transactions', 'account_id', id) ||
            await _isUsed('transactions', 'to_account_id', id) ||
            await _isUsed('recurring_rules', 'account_id', id) ||
            await _isUsed('debts', 'account_id', id) ||
            await _isUsed('debt_payments', 'account_id', id) ||
            await _isUsed('investment_entries', 'account_id', id);
        if (inUse) continue;
        await _db.accountsDao.setArchived(id, archived: true);
        accountsHidden++;
      }

      await (_db.delete(
        _db.importBatches,
      )..where((b) => b.id.equals(batchId))).go();
      return UndoResult(
        transactions: removed,
        categoriesHidden: categoriesHidden,
        accountsHidden: accountsHidden,
      );
    });
  }

  Future<bool> _hasActiveChild(int categoryId) async {
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM categories WHERE parent_id = ? AND is_archived = 0 '
          'LIMIT 1',
          variables: [Variable.withInt(categoryId)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Map<String, Object?> _savedMappings(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, Object?>.from(decoded) : {};
    } on FormatException {
      return {};
    }
  }

  /// The mapping used the last time for a file with these [headers], or null.
  /// It is only used when it fits the file ([columnCount] columns).
  Future<ImportMapping?> savedMapping(
    List<String> headers, {
    required int columnCount,
  }) async {
    final saved = _savedMappings(
      (await _db.settingsDao.getAll())[importMappingsKey],
    );
    return ImportMapping.fromJson(
      saved[headerSignature(headers)],
      columnCount: columnCount,
    );
  }

  /// Remembers [mapping] for files with these [headers]. The last
  /// [maxSavedMappings] layouts are kept.
  Future<void> saveMapping(List<String> headers, ImportMapping mapping) async {
    final saved = _savedMappings(
      (await _db.settingsDao.getAll())[importMappingsKey],
    );
    final signature = headerSignature(headers);
    saved
      ..remove(signature)
      ..[signature] = mapping.toJson();
    while (saved.length > maxSavedMappings) {
      saved.remove(saved.keys.first);
    }
    await _db.settingsDao.put(importMappingsKey, jsonEncode(saved));
  }
}
