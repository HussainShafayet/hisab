import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/settings/data/app_settings_table.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  Stream<Map<String, String>> watchAll() =>
      select(appSettings).watch().map(_toMap);

  Future<Map<String, String>> getAll() async =>
      _toMap(await select(appSettings).get());

  Map<String, String> _toMap(List<AppSettingRow> rows) => {
    for (final row in rows) row.key: row.value,
  };

  /// Saves [value] under [key], replacing what was there. A null [value]
  /// removes the row, so the default applies again.
  Future<void> put(String key, String? value) async {
    if (value == null) {
      await (delete(appSettings)..where((s) => s.key.equals(key))).go();
    } else {
      await into(appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
    }
  }
}
