import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';

void main() {
  group('defaults', () {
    test('are English, the phone theme, the calculator and Sunday', () {
      const defaults = AppPreferences.defaults;

      expect(defaults.language, AppLanguage.english);
      expect(defaults.theme, ThemePreference.system);
      expect(defaults.amountEntry, AmountEntry.calculator);
      expect(defaults.weekStart, WeekStart.sunday);
      expect(defaults.defaultAccountId, isNull);
    });

    test('have Fun mode on', () {
      expect(AppPreferences.defaults.funMode, isTrue);
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
        PreferenceKeys.amountEntry: 'keyboard',
        PreferenceKeys.weekStart: 'saturday',
      });

      expect(preferences.theme, ThemePreference.dark);
      expect(preferences.language, AppLanguage.bangla);
      expect(preferences.defaultAccountId, 7);
      expect(preferences.amountEntry, AmountEntry.keyboard);
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
        amountEntry: AmountEntry.keyboard,
        weekStart: WeekStart.monday,
      );

      expect(preferences.toMap(), {
        PreferenceKeys.theme: 'dark',
        PreferenceKeys.language: 'bangla',
        PreferenceKeys.defaultAccount: '3',
        PreferenceKeys.amountEntry: 'keyboard',
        PreferenceKeys.weekStart: 'monday',
        PreferenceKeys.funMode: 'true',
        PreferenceKeys.funSounds: 'true',
        PreferenceKeys.budgetAlerts: 'true',
        PreferenceKeys.habitAlerts: 'true',
        PreferenceKeys.wrappedAlert: 'true',
        PreferenceKeys.dailyReminder: 'false',
        PreferenceKeys.dailyReminderMinutes: '1260',
        PreferenceKeys.budgetRollover: 'false',
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
        amountEntry: AmountEntry.keyboard,
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

  group('Fun mode', () {
    test('is saved as true or false and read back', () {
      expect(
        const AppPreferences(funMode: false).toMap()[PreferenceKeys.funMode],
        'false',
      );
      expect(AppPreferences.defaults.toMap()[PreferenceKeys.funMode], 'true');
      expect(
        AppPreferences.fromMap({PreferenceKeys.funMode: 'false'}).funMode,
        isFalse,
      );
      expect(
        AppPreferences.fromMap({PreferenceKeys.funMode: 'true'}).funMode,
        isTrue,
      );
    });

    test('stays on for anything that is not "false"', () {
      expect(AppPreferences.fromMap({}).funMode, isTrue);
      expect(
        AppPreferences.fromMap({PreferenceKeys.funMode: 'banana'}).funMode,
        isTrue,
      );
    });

    test('is part of equality and copyWith', () {
      expect(
        AppPreferences.defaults.copyWith(funMode: false),
        isNot(AppPreferences.defaults),
      );
      expect(AppPreferences.defaults.copyWith(funMode: false).funMode, isFalse);
    });
  });

  group('Alerts', () {
    test('are on to start with, except the daily reminder', () {
      const p = AppPreferences.defaults;
      expect(p.funSounds, isTrue);
      expect(p.budgetAlerts, isTrue);
      expect(p.habitAlerts, isTrue);
      expect(p.wrappedAlert, isTrue);
      expect(p.dailyReminder, isFalse);
      expect(p.dailyReminderMinutes, 21 * 60);
    });

    test('are saved and read back', () {
      const p = AppPreferences(
        funSounds: false,
        budgetAlerts: false,
        habitAlerts: false,
        wrappedAlert: false,
        dailyReminder: true,
        dailyReminderMinutes: 8 * 60 + 30,
      );

      expect(AppPreferences.fromMap(p.toMap().cast<String, String>()), p);
    });

    test('stay on for anything that is not "false", off for not "true"', () {
      final p = AppPreferences.fromMap({
        PreferenceKeys.budgetAlerts: 'banana',
        PreferenceKeys.dailyReminder: 'banana',
      });

      expect(p.budgetAlerts, isTrue);
      expect(p.dailyReminder, isFalse);
    });

    test('keep the reminder time when what is saved is not a time', () {
      for (final bad in ['soon', '-5', '1440', '']) {
        expect(
          AppPreferences.fromMap({PreferenceKeys.dailyReminderMinutes: bad})
              .dailyReminderMinutes,
          21 * 60,
          reason: bad,
        );
      }
    });

    test('are part of equality and copyWith', () {
      final base = AppPreferences.defaults;
      for (final changed in [
        base.copyWith(funSounds: false),
        base.copyWith(budgetAlerts: false),
        base.copyWith(habitAlerts: false),
        base.copyWith(wrappedAlert: false),
        base.copyWith(dailyReminder: true),
        base.copyWith(dailyReminderMinutes: 600),
      ]) {
        expect(changed, isNot(base));
      }
    });
  });

  group('carrying a budget over', () {
    test('is off by default and saved as true or false', () {
      expect(AppPreferences.defaults.budgetRollover, isFalse);
      expect(
        AppPreferences.defaults.toMap()[PreferenceKeys.budgetRollover],
        'false',
      );
      expect(
        const AppPreferences(budgetRollover: true)
            .toMap()[PreferenceKeys.budgetRollover],
        'true',
      );
    });

    test('is on only when saved as exactly true', () {
      expect(
        AppPreferences.fromMap({PreferenceKeys.budgetRollover: 'true'})
            .budgetRollover,
        isTrue,
      );
      for (final saved in ['false', 'banana', '']) {
        expect(
          AppPreferences.fromMap({PreferenceKeys.budgetRollover: saved})
              .budgetRollover,
          isFalse,
        );
      }
      expect(AppPreferences.fromMap({}).budgetRollover, isFalse);
    });

    test('copyWith changes it and equality notices', () {
      final on = AppPreferences.defaults.copyWith(budgetRollover: true);

      expect(on.budgetRollover, isTrue);
      expect(on, isNot(AppPreferences.defaults));
      expect(on.copyWith(budgetRollover: false), AppPreferences.defaults);
    });
  });
}
