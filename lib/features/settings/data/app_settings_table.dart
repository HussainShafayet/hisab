import 'package:drift/drift.dart';

/// Preferences as name and value pairs. One row per preference; a missing row
/// means "use the default". The names are in `PreferenceKeys`.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
