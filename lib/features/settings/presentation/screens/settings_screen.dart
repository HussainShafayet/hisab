import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/app_info.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:intl/intl.dart';
import 'package:hishab/features/backup/data/auto_backup_gateway.dart';
import 'package:hishab/features/backup/data/auto_backup_service.dart';

/// Language, look, and how new transactions and weeks start.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _change(
    WidgetRef ref,
    AppPreferences Function(AppPreferences current) change,
  ) => ref.read(settingsRepositoryProvider).update(change);

  /// Switches an alert on or off. Switching one on asks the phone to allow
  /// notifications first (Android 13 and later ask at run time).
  Future<void> _setAlert(
    WidgetRef ref,
    bool on,
    AppPreferences Function(AppPreferences current, bool on) change,
  ) async {
    if (on) await ref.read(reminderSchedulerProvider).requestPermission();
    await _change(ref, (p) => change(p, on));
  }

  /// Asks twice-over clearly, then empties the app like a new install.
  Future<void> _eraseAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete all data?')),
        content: Text(
          tr(
            'Every account, entry, budget, loan, goal and setting on this '
            'phone is deleted, and the app starts empty, like a new install. '
            'This cannot be undone. Export a backup first if you may want '
            'anything back.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-erase'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete everything')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(backupRepositoryProvider).eraseEverything();
      if (context.mounted) context.go(AppRoutes.home);
      messenger.showMessage(tr('All data deleted.'));
    } on Object catch (error) {
      messenger.showError(describeError(error));
    }
  }

  Future<void> _chooseReminderTime(
    BuildContext context,
    WidgetRef ref,
    AppPreferences preferences,
  ) async {
    final minutes = preferences.dailyReminderMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    await _change(
      ref,
      (p) => p.copyWith(dailyReminderMinutes: picked.hour * 60 + picked.minute),
    );
  }

  Future<void> _chooseDefaultAccount(
    BuildContext context,
    WidgetRef ref,
    AppPreferences preferences,
  ) async {
    final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
    if (!context.mounted) return;
    // A sheet returns null when dismissed, so "the one used last" needs a
    // value of its own.
    const lastUsed = -1;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  tr('New transactions start with'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _AccountChoice(
                key: const ValueKey('default-account-last-used'),
                title: tr('The account used last'),
                selected: preferences.defaultAccountId == null,
                onTap: () => Navigator.of(context).pop(lastUsed),
              ),
              for (final account in accounts)
                _AccountChoice(
                  key: ValueKey('default-account-${account.id}'),
                  title: account.name,
                  selected: preferences.defaultAccountId == account.id,
                  onTap: () => Navigator.of(context).pop(account.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await _change(
      ref,
      (p) => p.copyWith(
        defaultAccountId: () => chosen == lastUsed ? null : chosen,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final accounts = ref.watch(accountsProvider(false)).value ?? const [];
    Account? defaultAccount;
    for (final item in accounts) {
      if (item.account.id == preferences.defaultAccountId) {
        defaultAccount = item.account;
      }
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Settings')),
        actions: const [HelpButton('settings')],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Section(
            title: tr('Appearance'),
            children: [
              _Choice<AppLanguage>(
                label: tr('Language'),
                keyPrefix: 'language',
                value: preferences.language,
                options: [
                  for (final language in AppLanguage.values)
                    (value: language, label: language.nativeName, icon: null),
                ],
                onChanged: (language) =>
                    _change(ref, (p) => p.copyWith(language: language)),
              ),
              _Choice<ThemePreference>(
                label: tr('Theme'),
                keyPrefix: 'theme',
                value: preferences.theme,
                options: [
                  (
                    value: ThemePreference.system,
                    label: tr('Same as the phone'),
                    icon: Icons.brightness_auto_outlined,
                  ),
                  (
                    value: ThemePreference.light,
                    label: tr('Light'),
                    icon: Icons.light_mode_outlined,
                  ),
                  (
                    value: ThemePreference.dark,
                    label: tr('Dark'),
                    icon: Icons.dark_mode_outlined,
                  ),
                ],
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(theme: value)),
              ),
            ],
          ),
          _Section(
            title: tr('Text size'),
            children: [
              _Choice<TextSize>(
                label: tr('How big the letters are'),
                hint: tr('On top of the size set in your phone.'),
                keyPrefix: 'text-size',
                value: preferences.textSize,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(textSize: value)),
                options: [
                  (value: TextSize.small, label: tr('Small'), icon: null),
                  (value: TextSize.normal, label: tr('Normal'), icon: null),
                  (value: TextSize.large, label: tr('Large'), icon: null),
                  (
                    value: TextSize.extraLarge,
                    label: tr('Extra large'),
                    icon: null,
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: tr('New transactions'),
            children: [
              ListTile(
                key: const ValueKey('default-account'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Account to start with')),
                subtitle: Text(
                  defaultAccount?.name ?? tr('The account used last'),
                  key: const ValueKey('default-account-value'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _chooseDefaultAccount(context, ref, preferences),
              ),
              _Choice<AmountEntry>(
                label: tr('Type the amount with'),
                hint: tr('You can switch any time while typing.'),
                keyPrefix: 'amount-entry',
                value: preferences.amountEntry,
                options: [
                  (
                    value: AmountEntry.keyboard,
                    label: tr('Keyboard'),
                    icon: Icons.keyboard_alt_outlined,
                  ),
                  (
                    value: AmountEntry.calculator,
                    label: tr('Calculator'),
                    icon: Icons.calculate_outlined,
                  ),
                ],
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(amountEntry: value)),
              ),
            ],
          ),
          _Section(
            title: tr('Calendar'),
            children: [
              _Choice<WeekStart>(
                label: tr('The week starts on'),
                hint: tr('Used for "this week" on Home.'),
                keyPrefix: 'week-start',
                value: preferences.weekStart,
                options: [
                  (
                    value: WeekStart.saturday,
                    label: tr('Saturday'),
                    icon: null,
                  ),
                  (value: WeekStart.sunday, label: tr('Sunday'), icon: null),
                  (value: WeekStart.monday, label: tr('Monday'), icon: null),
                ],
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(weekStart: value)),
              ),
            ],
          ),
          _Section(
            title: tr('Budget'),
            children: [
              SwitchListTile(
                key: const ValueKey('settings-rollover'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.redo),
                title: Text(tr('Carry over what is left')),
                subtitle: Text(
                  tr("Money you do not spend is added to next month's budget."),
                ),
                value: preferences.budgetRollover,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(budgetRollover: value)),
              ),
            ],
          ),
          _Section(
            title: tr('Privacy'),
            children: [
              SwitchListTile(
                key: const ValueKey('hide-balances'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.visibility_off_outlined),
                title: Text(tr('Hide balances')),
                subtitle: Text(
                  tr(
                    'Shows dots instead of your balances on Home and on '
                    'Accounts, for when someone is looking. The eye on Home '
                    'switches it too.',
                  ),
                ),
                value: preferences.hideBalances,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(hideBalances: value)),
              ),
              SwitchListTile(
                key: const ValueKey('hide-income'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.lock_outline),
                title: Text(tr('Hide income')),
                subtitle: Text(
                  tr(
                    'Shows dots and a bar instead of your income. The bar '
                    'says how much of it is spent, which only you will '
                    'understand. Tap the dots to see the amount for a few '
                    'seconds.',
                  ),
                ),
                value: preferences.hideIncome,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(hideIncome: value)),
              ),
            ],
          ),
          _Section(
            title: tr('Fun'),
            children: [
              SwitchListTile(
                key: const ValueKey('fun-mode'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.celebration_outlined),
                title: Text(tr('Fun mode')),
                subtitle: Text(
                  tr(
                    'Takka the coin, little jokes and a bit of confetti. '
                    'Turn it off for a plain app.',
                  ),
                ),
                value: preferences.funMode,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(funMode: value)),
              ),
            ],
          ),
          _Section(
            title: tr('Alerts'),
            children: [
              SwitchListTile(
                key: const ValueKey('fun-sounds'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.music_note_outlined),
                title: Text(tr('Funny alert sounds')),
                subtitle: Text(
                  tr(
                    'Each alert plays its own silly sound. Off uses your '
                    "phone's usual one.",
                  ),
                ),
                value: preferences.funSounds,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(funSounds: value)),
              ),
              SwitchListTile(
                key: const ValueKey('budget-alerts'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.speed_outlined),
                title: Text(tr('Budget alerts')),
                subtitle: Text(
                  tr(
                    "A word when this month's budget is nearly used up or "
                    'crossed.',
                  ),
                ),
                value: preferences.budgetAlerts,
                onChanged: (value) => _setAlert(
                  ref,
                  value,
                  (p, on) => p.copyWith(budgetAlerts: on),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('habit-alerts'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.repeat),
                title: Text(tr('Habit alerts')),
                subtitle: Text(
                  tr(
                    'When the same kind of spending keeps coming back, like '
                    'the fifth rickshaw this week.',
                  ),
                ),
                value: preferences.habitAlerts,
                onChanged: (value) => _setAlert(
                  ref,
                  value,
                  (p, on) => p.copyWith(habitAlerts: on),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('wrapped-alert'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: Text(tr('Month wrapped alert')),
                subtitle: Text(
                  tr("A nudge when your month's wrapped is ready."),
                ),
                value: preferences.wrappedAlert,
                onChanged: (value) => _setAlert(
                  ref,
                  value,
                  (p, on) => p.copyWith(wrappedAlert: on),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('daily-reminder'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.edit_notifications_outlined),
                title: Text(tr('Daily reminder')),
                subtitle: Text(
                  tr(
                    "An evening nudge to write the day's entries, only on "
                    'days you have not.',
                  ),
                ),
                value: preferences.dailyReminder,
                onChanged: (value) => _setAlert(
                  ref,
                  value,
                  (p, on) => p.copyWith(dailyReminder: on),
                ),
              ),
              if (preferences.dailyReminder)
                ListTile(
                  key: const ValueKey('daily-reminder-time'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(tr('Reminder time')),
                  subtitle: Text(
                    TimeOfDay(
                      hour: preferences.dailyReminderMinutes ~/ 60,
                      minute: preferences.dailyReminderMinutes % 60,
                    ).format(context),
                  ),
                  onTap: () => _chooseReminderTime(context, ref, preferences),
                ),
            ],
          ),
          _Section(
            title: tr('Data'),
            children: [
              SwitchListTile(
                key: const ValueKey('auto-backup'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.cloud_sync_outlined),
                title: Text(tr('Automatic backup')),
                subtitle: _AutoBackupNote(
                  status: ref.watch(autoBackupStatusProvider).value,
                ),
                value: preferences.autoBackup,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(autoBackup: value)),
              ),
              SwitchListTile(
                key: const ValueKey('backup-reminder'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.backup_outlined),
                title: Text(tr('Remind me to back up')),
                subtitle: Text(
                  tr('A card on Home when it has been two weeks.'),
                ),
                value: preferences.backupReminder,
                onChanged: (value) =>
                    _change(ref, (p) => p.copyWith(backupReminder: value)),
              ),
              ListTile(
                key: const ValueKey('open-backup'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.save_alt),
                title: Text(tr('Backup & export')),
                subtitle: Text(tr('Keep your data safe')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.backup),
              ),
              ListTile(
                key: const ValueKey('erase-all'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  tr('Delete all data'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: Text(tr('Start again, empty, like a new install.')),
                onTap: () => _eraseAll(context, ref),
              ),
            ],
          ),
          _Section(
            title: tr('About'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(tr('Hishab')),
                subtitle: Text(
                  tr('Version {version}', {'version': appVersion}),
                  key: const ValueKey('app-version'),
                ),
              ),
              ListTile(
                key: const ValueKey('licenses'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(tr('Open-source licenses')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: tr('Hishab'),
                  applicationVersion: appVersion,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  tr(
                    'Hishab works without the internet. Your data stays on '
                    'this phone. Keep a backup somewhere safe.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountChoice extends StatelessWidget {
  const _AccountChoice({
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}

/// A titled group of settings in a card.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Option<T> = ({T value, String label, IconData? icon});

/// A setting with a few choices, shown as chips that wrap instead of
/// squeezing on a narrow screen or with large text.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.keyPrefix,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final String keyPrefix;
  final T value;
  final List<_Option<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          if (hint != null)
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in options)
                ChoiceChip(
                  key: ValueKey('$keyPrefix-${(option.value as Enum).name}'),
                  showCheckmark: false,
                  avatar: option.icon == null
                      ? null
                      : Icon(option.icon, size: 18),
                  label: Text(option.label),
                  selected: option.value == value,
                  onSelected: (_) => onChanged(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the automatic backup does, and how it went last time.
class _AutoBackupNote extends StatelessWidget {
  const _AutoBackupNote({required this.status});

  final AutoBackupStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = status?.problem;
    final saved = status?.lastSaved;
    final text = problem != null
        ? tr('Could not save: {reason}', {
            'reason': switch (problem) {
              AutoBackupProblem.oldAndroid => tr('Needs Android 10 or newer.'),
              AutoBackupProblem.failed => tr(
                'The phone did not let the file be saved.',
              ),
            },
          })
        : saved != null
        ? tr('Saved {when}.', {
            'when': localizeDigits(DateFormat('d MMM, h:mm a').format(saved)),
          })
        : tr('Not saved yet. It saves when you leave the app.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(
            'Saves a copy of your data in Downloads/Hishab whenever you leave '
            'the app, so it is still there if the app is removed. The file is '
            'not locked: anyone who opens Files can read it. To get it back, '
            'use Backup & export and choose Restore.',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          key: const ValueKey('auto-backup-status'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: problem != null
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
