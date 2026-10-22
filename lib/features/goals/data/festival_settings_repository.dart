import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:hishab/features/goals/domain/festival_settings.dart';

/// The festival settings, kept in the app settings under one name.
class FestivalSettingsRepository {
  FestivalSettingsRepository(this._db);

  final AppDatabase _db;

  Stream<FestivalSettings> watch() => _db.settingsDao.watchAll().map(
    (saved) => FestivalSettings.fromJson(saved[festivalSettingsKey]),
  );

  Future<FestivalSettings> get() async => FestivalSettings.fromJson(
    (await _db.settingsDao.getAll())[festivalSettingsKey],
  );

  Future<void> _save(FestivalSettings settings) => _db.settingsDao.put(
    festivalSettingsKey,
    settings.isEmpty ? null : settings.toJson(),
  );

  Future<void> hide(Festival festival) async =>
      _save((await get()).hiding(festival));

  Future<void> show(Festival festival) async =>
      _save((await get()).showing(festival));

  Future<void> showAll() async => _save((await get()).showingAll());

  /// Sets the day of [festival] by hand.
  Future<void> setDate(Festival festival, DateTime day) async =>
      _save((await get()).withDate(festival, day));

  /// Goes back to the day by the calendar.
  Future<void> clearDate(Festival festival) async =>
      _save((await get()).withoutDate(festival));
}
