import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';

/// Reads and saves the preferences chosen in Settings.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// The preferences now, and again whenever one changes.
  Stream<AppPreferences> watch() =>
      _db.settingsDao.watchAll().map(AppPreferences.fromMap);

  Future<AppPreferences> load() async =>
      AppPreferences.fromMap(await _db.settingsDao.getAll());

  /// Saves [preferences], all of it in one go.
  Future<void> save(AppPreferences preferences) {
    return _db.transaction(() async {
      for (final entry in preferences.toMap().entries) {
        await _db.settingsDao.put(entry.key, entry.value);
      }
    });
  }

  /// Changes some preferences and keeps the rest, using what is saved now.
  Future<AppPreferences> update(
    AppPreferences Function(AppPreferences current) change,
  ) async {
    final next = change(await load());
    await save(next);
    return next;
  }
}
