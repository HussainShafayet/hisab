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

/// How big the letters of the app are, on top of the phone's own setting.
enum TextSize {
  small(0.9),
  normal(1.0),
  large(1.15),
  extraLarge(1.3);

  const TextSize(this.scale);

  /// What the size of every text is multiplied by.
  final double scale;
}

/// The names under which preferences are saved. Never rename one without a
/// migration.
abstract final class PreferenceKeys {
  static const theme = 'theme';
  static const language = 'language';
  static const defaultAccount = 'default_account';
  static const amountEntry = 'amount_entry';
  static const weekStart = 'week_start';
  static const funMode = 'fun_mode';
  static const funSounds = 'fun_sounds';
  static const budgetAlerts = 'budget_alerts';
  static const habitAlerts = 'habit_alerts';
  static const wrappedAlert = 'wrapped_alert';
  static const dailyReminder = 'daily_reminder';
  static const dailyReminderMinutes = 'daily_reminder_minutes';
  static const budgetRollover = 'budget_rollover';
  static const textSize = 'text_size';
  static const hideBalances = 'hide_balances';
  static const hideIncome = 'hide_income';
  static const backupReminder = 'backup_reminder';
  static const homeMoreOpen = 'home_more_open';
}

/// What the user chose in Settings.
class AppPreferences {
  const AppPreferences({
    this.theme = ThemePreference.system,
    this.language = AppLanguage.english,
    this.defaultAccountId,
    this.amountEntry = AmountEntry.calculator,
    this.weekStart = WeekStart.sunday,
    this.funMode = true,
    this.funSounds = true,
    this.budgetAlerts = true,
    this.habitAlerts = true,
    this.wrappedAlert = true,
    this.dailyReminder = false,
    this.dailyReminderMinutes = 21 * 60,
    this.budgetRollover = false,
    this.textSize = TextSize.normal,
    this.hideBalances = false,
    this.hideIncome = false,
    this.backupReminder = true,
    this.homeMoreOpen = false,
  });

  static const defaults = AppPreferences();

  final ThemePreference theme;
  final AppLanguage language;

  /// The account a new transaction starts with. Null means the one used last.
  final int? defaultAccountId;
  final AmountEntry amountEntry;
  final WeekStart weekStart;

  /// Takka the coin, little jokes and celebrations. Off makes a plain app.
  final bool funMode;

  /// Notifications play their own funny sound. Off uses the phone's usual one.
  final bool funSounds;

  /// A notification when the month's budget is nearly used up or crossed.
  final bool budgetAlerts;

  /// A notification when the same kind of spending keeps coming back.
  final bool habitAlerts;

  /// A notification when the month's wrapped is ready.
  final bool wrappedAlert;

  /// A reminder every evening to write the day's entries, unless they were
  /// already written.
  final bool dailyReminder;

  /// The time of that reminder, in minutes after midnight.
  final int dailyReminderMinutes;

  /// What is left of a budget at the end of a month is added to the same
  /// budget of the next month.
  final bool budgetRollover;

  /// The size of the letters, on top of the phone's own setting.
  final TextSize textSize;

  /// Home shows dots instead of the balances.
  final bool hideBalances;

  /// Income is shown as dots and a bar (how much of it is spent) instead of
  /// amounts, until it is tapped.
  final bool hideIncome;

  /// A card on Home asks for a backup when it has been two weeks.
  final bool backupReminder;

  /// The part of Home with the streak, tips and the mascot is open. It is
  /// closed until the person opens it.
  final bool homeMoreOpen;

  AppPreferences copyWith({
    ThemePreference? theme,
    AppLanguage? language,
    int? Function()? defaultAccountId,
    AmountEntry? amountEntry,
    WeekStart? weekStart,
    bool? funMode,
    bool? funSounds,
    bool? budgetAlerts,
    bool? habitAlerts,
    bool? wrappedAlert,
    bool? dailyReminder,
    int? dailyReminderMinutes,
    bool? budgetRollover,
    TextSize? textSize,
    bool? hideBalances,
    bool? hideIncome,
    bool? backupReminder,
    bool? homeMoreOpen,
  }) => AppPreferences(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    defaultAccountId: defaultAccountId == null
        ? this.defaultAccountId
        : defaultAccountId(),
    amountEntry: amountEntry ?? this.amountEntry,
    weekStart: weekStart ?? this.weekStart,
    funMode: funMode ?? this.funMode,
    funSounds: funSounds ?? this.funSounds,
    budgetAlerts: budgetAlerts ?? this.budgetAlerts,
    habitAlerts: habitAlerts ?? this.habitAlerts,
    wrappedAlert: wrappedAlert ?? this.wrappedAlert,
    dailyReminder: dailyReminder ?? this.dailyReminder,
    dailyReminderMinutes: dailyReminderMinutes ?? this.dailyReminderMinutes,
    budgetRollover: budgetRollover ?? this.budgetRollover,
    textSize: textSize ?? this.textSize,
    hideBalances: hideBalances ?? this.hideBalances,
    hideIncome: hideIncome ?? this.hideIncome,
    backupReminder: backupReminder ?? this.backupReminder,
    homeMoreOpen: homeMoreOpen ?? this.homeMoreOpen,
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
      // Only an explicit "false" turns it off.
      funMode: saved[PreferenceKeys.funMode] != 'false',
      funSounds: saved[PreferenceKeys.funSounds] != 'false',
      budgetAlerts: saved[PreferenceKeys.budgetAlerts] != 'false',
      habitAlerts: saved[PreferenceKeys.habitAlerts] != 'false',
      wrappedAlert: saved[PreferenceKeys.wrappedAlert] != 'false',
      // Off until the person turns it on.
      dailyReminder: saved[PreferenceKeys.dailyReminder] == 'true',
      dailyReminderMinutes: _minutesOfDay(
        saved[PreferenceKeys.dailyReminderMinutes],
        defaults.dailyReminderMinutes,
      ),
      // Off until the person turns it on.
      budgetRollover: saved[PreferenceKeys.budgetRollover] == 'true',
      textSize: pick(
        TextSize.values,
        PreferenceKeys.textSize,
        defaults.textSize,
      ),
      // Off until the person turns it on.
      hideBalances: saved[PreferenceKeys.hideBalances] == 'true',
      hideIncome: saved[PreferenceKeys.hideIncome] == 'true',
      // Only an explicit "false" turns it off.
      backupReminder: saved[PreferenceKeys.backupReminder] != 'false',
      // Closed until the person opens it.
      homeMoreOpen: saved[PreferenceKeys.homeMoreOpen] == 'true',
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
    PreferenceKeys.funMode: funMode.toString(),
    PreferenceKeys.funSounds: funSounds.toString(),
    PreferenceKeys.budgetAlerts: budgetAlerts.toString(),
    PreferenceKeys.habitAlerts: habitAlerts.toString(),
    PreferenceKeys.wrappedAlert: wrappedAlert.toString(),
    PreferenceKeys.dailyReminder: dailyReminder.toString(),
    PreferenceKeys.dailyReminderMinutes: dailyReminderMinutes.toString(),
    PreferenceKeys.budgetRollover: budgetRollover.toString(),
    PreferenceKeys.textSize: textSize.name,
    PreferenceKeys.hideBalances: hideBalances.toString(),
    PreferenceKeys.hideIncome: hideIncome.toString(),
    PreferenceKeys.backupReminder: backupReminder.toString(),
    PreferenceKeys.homeMoreOpen: homeMoreOpen.toString(),
  };

  /// A saved time of day, or [fallback] when it is missing or not a time.
  static int _minutesOfDay(String? saved, int fallback) {
    final minutes = int.tryParse(saved ?? '');
    return minutes != null && minutes >= 0 && minutes < 24 * 60
        ? minutes
        : fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.theme == theme &&
      other.language == language &&
      other.defaultAccountId == defaultAccountId &&
      other.amountEntry == amountEntry &&
      other.weekStart == weekStart &&
      other.funMode == funMode &&
      other.funSounds == funSounds &&
      other.budgetAlerts == budgetAlerts &&
      other.habitAlerts == habitAlerts &&
      other.wrappedAlert == wrappedAlert &&
      other.dailyReminder == dailyReminder &&
      other.dailyReminderMinutes == dailyReminderMinutes &&
      other.budgetRollover == budgetRollover &&
      other.textSize == textSize &&
      other.hideBalances == hideBalances &&
      other.hideIncome == hideIncome &&
      other.backupReminder == backupReminder &&
      other.homeMoreOpen == homeMoreOpen;

  @override
  int get hashCode => Object.hash(
    theme,
    language,
    defaultAccountId,
    amountEntry,
    weekStart,
    funMode,
    funSounds,
    budgetAlerts,
    habitAlerts,
    wrappedAlert,
    dailyReminder,
    dailyReminderMinutes,
    budgetRollover,
    textSize,
    hideBalances,
    hideIncome,
    backupReminder,
    homeMoreOpen,
  );
}
