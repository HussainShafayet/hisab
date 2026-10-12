import 'package:hishab/core/l10n/app_language.dart';

/// How the app looks: follow the phone, or always light or dark.
enum ThemePreference { system, light, dark }

/// How the amount of a new transaction is typed.
enum AmountEntry {
  /// A plain number on the keyboard, with the calculator one tap away.
  keyboard,

  /// The calculator keypad from the start.
  calculator,
}

/// The day weeks start on, for "this week".
enum WeekStart {
  saturday(DateTime.saturday),
  sunday(DateTime.sunday),
  monday(DateTime.monday);

  const WeekStart(this.weekday);

  /// A `DateTime.weekday` value.
  final int weekday;
}

/// The names under which preferences are saved. Never rename one without a
/// migration.
abstract final class PreferenceKeys {
  static const theme = 'theme';
  static const language = 'language';
  static const defaultAccount = 'default_account';
  static const amountEntry = 'amount_entry';
  static const weekStart = 'week_start';
}

/// What the user chose in Settings.
class AppPreferences {
  const AppPreferences({
    this.theme = ThemePreference.system,
    this.language = AppLanguage.english,
    this.defaultAccountId,
    this.amountEntry = AmountEntry.keyboard,
    this.weekStart = WeekStart.sunday,
  });

  static const defaults = AppPreferences();

  final ThemePreference theme;
  final AppLanguage language;

  /// The account a new transaction starts with. Null means the one used last.
  final int? defaultAccountId;
  final AmountEntry amountEntry;
  final WeekStart weekStart;

  AppPreferences copyWith({
    ThemePreference? theme,
    AppLanguage? language,
    int? Function()? defaultAccountId,
    AmountEntry? amountEntry,
    WeekStart? weekStart,
  }) => AppPreferences(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    defaultAccountId: defaultAccountId == null
        ? this.defaultAccountId
        : defaultAccountId(),
    amountEntry: amountEntry ?? this.amountEntry,
    weekStart: weekStart ?? this.weekStart,
  );

  /// Reads saved preferences. Anything missing or not understood (a value
  /// from a newer version of the app, say) falls back to its default.
  factory AppPreferences.fromMap(Map<String, String> saved) {
    T pick<T extends Enum>(List<T> values, String key, T fallback) {
      final name = saved[key];
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    return AppPreferences(
      theme: pick(ThemePreference.values, PreferenceKeys.theme, defaults.theme),
      language: pick(
        AppLanguage.values,
        PreferenceKeys.language,
        defaults.language,
      ),
      defaultAccountId: int.tryParse(
        saved[PreferenceKeys.defaultAccount] ?? '',
      ),
      amountEntry: pick(
        AmountEntry.values,
        PreferenceKeys.amountEntry,
        defaults.amountEntry,
      ),
      weekStart: pick(
        WeekStart.values,
        PreferenceKeys.weekStart,
        defaults.weekStart,
      ),
    );
  }

  /// What to save: every preference by its key, with null for one that is
  /// not set (the default account), which means "remove it".
  Map<String, String?> toMap() => {
    PreferenceKeys.theme: theme.name,
    PreferenceKeys.language: language.name,
    PreferenceKeys.defaultAccount: defaultAccountId?.toString(),
    PreferenceKeys.amountEntry: amountEntry.name,
    PreferenceKeys.weekStart: weekStart.name,
  };

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.theme == theme &&
      other.language == language &&
      other.defaultAccountId == defaultAccountId &&
      other.amountEntry == amountEntry &&
      other.weekStart == weekStart;

  @override
  int get hashCode =>
      Object.hash(theme, language, defaultAccountId, amountEntry, weekStart);
}
