import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/app_database.dart';

/// The single [AppDatabase] of the app. `main()` creates and opens it, then
/// overrides this provider; tests override it with an in-memory database.
/// Throwing by default means a forgotten override fails loudly instead of
/// silently opening a second connection to the same file.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override appDatabaseProvider in the ProviderScope');
});

/// Emits whenever transactions, accounts, categories or budgets change.
/// Screens that calculate several things at once (the dashboard, the reports)
/// watch it so they calculate again after any change.
final dataChangesProvider = StreamProvider<void>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.tableUpdates(
    TableUpdateQuery.onAllTables([
      db.transactions,
      db.accounts,
      db.categories,
      db.budgets,
      db.challenges,
    ]),
  );
});
