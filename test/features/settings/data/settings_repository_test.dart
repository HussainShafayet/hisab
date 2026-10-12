import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  group('the settings table', () {
    test('starts empty', () async {
      expect(await db.settingsDao.getAll(), isEmpty);
    });

    test('keeps a value under its name and replaces it', () async {
      await db.settingsDao.put('theme', 'dark');
      await db.settingsDao.put('theme', 'light');

      expect(await db.settingsDao.getAll(), {'theme': 'light'});
    });

    test('removes a row when the value is null', () async {
      await db.settingsDao.put('theme', 'dark');
      await db.settingsDao.put('language', 'bangla');

      await db.settingsDao.put('theme', null);

      expect(await db.settingsDao.getAll(), {'language': 'bangla'});
    });

    test('removing what is not there does nothing', () async {
      await db.settingsDao.put('theme', null);

      expect(await db.settingsDao.getAll(), isEmpty);
    });
  });

  group('load', () {
    test('gives the defaults when nothing was saved', () async {
      expect(await repo.load(), AppPreferences.defaults);
    });

    test('gives what was saved', () async {
      await db.settingsDao.put(PreferenceKeys.language, 'bangla');
      await db.settingsDao.put(PreferenceKeys.weekStart, 'monday');

      final preferences = await repo.load();

      expect(preferences.language, AppLanguage.bangla);
      expect(preferences.weekStart, WeekStart.monday);
      expect(preferences.theme, ThemePreference.system);
    });

    test('ignores a value it cannot read', () async {
      await db.settingsDao.put(PreferenceKeys.theme, 'neon');

      expect((await repo.load()).theme, ThemePreference.system);
    });
  });

  group('save', () {
    test('writes everything and reads it back', () async {
      const preferences = AppPreferences(
        theme: ThemePreference.dark,
        language: AppLanguage.bangla,
        defaultAccountId: 5,
        amountEntry: AmountEntry.calculator,
        weekStart: WeekStart.saturday,
      );

      await repo.save(preferences);

      expect(await repo.load(), preferences);
    });

    test('removes the default account when there is none', () async {
      await repo.save(const AppPreferences(defaultAccountId: 5));

      await repo.save(const AppPreferences());

      expect(
        (await db.settingsDao.getAll()).containsKey(
          PreferenceKeys.defaultAccount,
        ),
        isFalse,
      );
      expect((await repo.load()).defaultAccountId, isNull);
    });
  });

  group('update', () {
    test('changes one preference and keeps the others', () async {
      await repo.save(
        const AppPreferences(
          language: AppLanguage.bangla,
          weekStart: WeekStart.monday,
        ),
      );

      final next = await repo.update(
        (current) => current.copyWith(theme: ThemePreference.dark),
      );

      expect(next.theme, ThemePreference.dark);
      expect(next.language, AppLanguage.bangla);
      expect(next.weekStart, WeekStart.monday);
      expect(await repo.load(), next);
    });

    test('can clear the default account', () async {
      await repo.save(const AppPreferences(defaultAccountId: 9));

      await repo.update(
        (current) => current.copyWith(defaultAccountId: () => null),
      );

      expect((await repo.load()).defaultAccountId, isNull);
    });
  });

  group('watch', () {
    test('starts with what is saved and emits after each change', () async {
      final seen = <AppPreferences>[];
      final subscription = repo.watch().listen(seen.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repo.update((p) => p.copyWith(language: AppLanguage.bangla));
      await pumpEventQueue();
      await repo.update((p) => p.copyWith(theme: ThemePreference.light));
      await pumpEventQueue();

      expect(seen.first, AppPreferences.defaults);
      expect(seen.last.language, AppLanguage.bangla);
      expect(seen.last.theme, ThemePreference.light);
    });
  });

  group('backup and restore', () {
    test('settings are not part of a restore, so they stay', () async {
      await repo.save(const AppPreferences(language: AppLanguage.bangla));

      // Restoring replaces accounts, categories, transactions and budgets.
      await db.delete(db.budgets).go();
      await db.delete(db.transactions).go();
      await db.delete(db.categories).go();
      await db.delete(db.accounts).go();

      expect((await repo.load()).language, AppLanguage.bangla);
    });
  });
}
