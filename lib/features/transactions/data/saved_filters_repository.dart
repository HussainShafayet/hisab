import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/saved_filter.dart';

/// The filters the person saved, kept in the app settings (so a backup holds
/// them) under one name.
class SavedFiltersRepository {
  SavedFiltersRepository(this._db);

  final AppDatabase _db;

  static const settingKey = 'saved_filters';

  Stream<List<SavedFilter>> watch() => _db.settingsDao.watchAll().map(
    (saved) => decodeSavedFilters(saved[settingKey]),
  );

  Future<List<SavedFilter>> getAll() async =>
      decodeSavedFilters((await _db.settingsDao.getAll())[settingKey]);

  /// Saves [filter] under [name]. One with the same name is replaced.
  Future<void> save(String name, TransactionFilter filter) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final shortName = trimmed.length > maxSavedFilterNameLength
        ? trimmed.substring(0, maxSavedFilterNameLength)
        : trimmed;
    final all = withSavedFilter(
      await getAll(),
      SavedFilter(name: shortName, filter: filter),
    );
    await _db.settingsDao.put(settingKey, encodeSavedFilters(all));
  }

  Future<void> remove(String name) async {
    final all = [
      for (final f in await getAll())
        if (f.name != name) f,
    ];
    await _db.settingsDao.put(
      settingKey,
      all.isEmpty ? null : encodeSavedFilters(all),
    );
  }
}
