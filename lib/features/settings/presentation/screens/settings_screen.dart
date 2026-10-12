import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/app_info.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// Language, look, and how new transactions and weeks start.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _change(
    WidgetRef ref,
    AppPreferences Function(AppPreferences current) change,
  ) => ref.read(settingsRepositoryProvider).update(change);

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
      appBar: AppBar(title: Text(tr('Settings'))),
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
                hint: tr('The calculator is always one tap away.'),
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
