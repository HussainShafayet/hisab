import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';

void main() {
  group('defaults', () {
    test('are English, the phone theme, the keyboard and Sunday', () {
      const defaults = AppPreferences.defaults;

      expect(defaults.language, AppLanguage.english);
      expect(defaults.theme, ThemePreference.system);
      expect(defaults.amountEntry, AmountEntry.keyboard);
      expect(defaults.weekStart, WeekStart.sunday);
      expect(defaults.defaultAccountId, isNull);
    });

    test('are what nothing saved gives', () {
      expect(AppPreferences.fromMap({}), AppPreferences.defaults);
    });
  });

  group('WeekStart', () {
    test('knows its weekday', () {
      expect(WeekStart.saturday.weekday, DateTime.saturday);
      expect(WeekStart.sunday.weekday, DateTime.sunday);
      expect(WeekStart.monday.weekday, DateTime.monday);
    });
  });

  group('fromMap', () {
    test('reads every preference', () {
      final preferences = AppPreferences.fromMap({
        PreferenceKeys.theme: 'dark',
        PreferenceKeys.language: 'bangla',
        PreferenceKeys.defaultAccount: '7',
        PreferenceKeys.amountEntry: 'calculator',
        PreferenceKeys.weekStart: 'saturday',
      });

      expect(preferences.theme, ThemePreference.dark);
      expect(preferences.language, AppLanguage.bangla);
      expect(preferences.defaultAccountId, 7);
      expect(preferences.amountEntry, AmountEntry.calculator);
      expect(preferences.weekStart, WeekStart.saturday);
    });

    test('falls back to the default for a value it does not know', () {
      final preferences = AppPreferences.fromMap({
        PreferenceKeys.theme: 'neon',
        PreferenceKeys.language: 'klingon',
        PreferenceKeys.amountEntry: '',
        PreferenceKeys.weekStart: 'friday',
        PreferenceKeys.defaultAccount: 'not a number',
      });

      expect(preferences, AppPreferences.defaults);
    });

    test('keeps what it knows when something else is wrong', () {
      final preferences = AppPreferences.fromMap({
        PreferenceKeys.theme: 'light',
        PreferenceKeys.language: 'klingon',
      });

      expect(preferences.theme, ThemePreference.light);
      expect(preferences.language, AppLanguage.english);
    });

    test('ignores keys it has never heard of', () {
      expect(
        AppPreferences.fromMap({'from_the_future': 'yes'}),
        AppPreferences.defaults,
      );
    });
  });

  group('toMap', () {
    test('writes every preference by its key', () {
      const preferences = AppPreferences(
        theme: ThemePreference.dark,
        language: AppLanguage.bangla,
        defaultAccountId: 3,
        amountEntry: AmountEntry.calculator,
        weekStart: WeekStart.monday,
      );

      expect(preferences.toMap(), {
        PreferenceKeys.theme: 'dark',
        PreferenceKeys.language: 'bangla',
        PreferenceKeys.defaultAccount: '3',
        PreferenceKeys.amountEntry: 'calculator',
        PreferenceKeys.weekStart: 'monday',
      });
    });

    test('has null for the default account when none is set', () {
      expect(
        AppPreferences.defaults.toMap()[PreferenceKeys.defaultAccount],
        isNull,
      );
    });

    test('can be read back', () {
      const preferences = AppPreferences(
        theme: ThemePreference.light,
        language: AppLanguage.bangla,
        defaultAccountId: 12,
        amountEntry: AmountEntry.calculator,
        weekStart: WeekStart.saturday,
      );
      final saved = {
        for (final entry in preferences.toMap().entries)
          if (entry.value != null) entry.key: entry.value!,
      };

      expect(AppPreferences.fromMap(saved), preferences);
    });
  });

  group('copyWith', () {
    test('changes only what is given', () {
      final changed = AppPreferences.defaults.copyWith(
        language: AppLanguage.bangla,
      );

      expect(changed.language, AppLanguage.bangla);
      expect(changed.theme, ThemePreference.system);
      expect(changed.weekStart, WeekStart.sunday);
    });

    test('can set and clear the default account', () {
      final set = AppPreferences.defaults.copyWith(defaultAccountId: () => 4);
      expect(set.defaultAccountId, 4);

      final cleared = set.copyWith(defaultAccountId: () => null);
      expect(cleared.defaultAccountId, isNull);

      // Not mentioned: kept.
      expect(set.copyWith(theme: ThemePreference.dark).defaultAccountId, 4);
    });
  });

  group('equality', () {
    test('compares by value', () {
      expect(
        const AppPreferences(weekStart: WeekStart.monday),
        const AppPreferences(weekStart: WeekStart.monday),
      );
      expect(
        const AppPreferences(weekStart: WeekStart.monday),
        isNot(const AppPreferences()),
      );
      expect(
        const AppPreferences(weekStart: WeekStart.monday).hashCode,
        const AppPreferences(weekStart: WeekStart.monday).hashCode,
      );
    });
  });
}
