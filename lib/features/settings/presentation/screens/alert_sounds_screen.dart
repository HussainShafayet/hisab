import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_sound_mode.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:hishab/features/settings/presentation/providers/alert_sound_providers.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// The sound of each alert, with a button to hear it, and whether the phone
/// lets Hishab show notifications at all.
class AlertSoundsScreen extends ConsumerStatefulWidget {
  const AlertSoundsScreen({super.key});

  @override
  ConsumerState<AlertSoundsScreen> createState() => _AlertSoundsScreenState();
}

class _AlertSoundsScreenState extends ConsumerState<AlertSoundsScreen> {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _checkAllowed();
  }

  Future<void> _checkAllowed() async {
    final allowed = await ref
        .read(reminderSchedulerProvider)
        .notificationsAllowed();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _allow() async {
    final allowed = await ref
        .read(reminderSchedulerProvider)
        .requestPermission();
    if (mounted) setState(() => _allowed = allowed);
  }

  /// Shows the alert right now with the sound chosen for it.
  Future<void> _test(AlertKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheduler = ref.read(reminderSchedulerProvider);
    if (!await scheduler.notificationsAllowed() &&
        !await scheduler.requestPermission()) {
      if (!mounted) return;
      setState(() => _allowed = false);
      messenger.showError(
        tr(
          'Notifications are off for Hishab. Turn them on in the phone '
          'settings, under Apps > Hishab > Notifications.',
        ),
      );
      return;
    }
    if (mounted) setState(() => _allowed = true);
    await scheduler.showNow(
      Reminder(
        id: 800000000 + kind.index,
        kind: kind,
        title: tr('Test: {name}', {'name': kind.label}),
        body: tr('This is how this alert sounds.'),
        when: ref.read(clockProvider)(),
      ),
      funSounds: ref.read(preferencesProvider).funSounds,
      overrides: ref.read(alertSoundOverridesProvider).value ?? const {},
    );
    messenger.showMessage(
      tr('Sent. If you hear nothing, check the phone is not on silent.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final funSounds = ref.watch(preferencesProvider.select((p) => p.funSounds));
    final overrides = ref.watch(alertSoundOverridesProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Alert sounds')),
        actions: const [HelpButton('alerts')],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Card(
            key: const ValueKey('alerts-status'),
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _allowed == false
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    color: _allowed == false
                        ? colors.warning
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _allowed == null
                          ? tr('Checking notifications...')
                          : _allowed!
                          ? tr('Notifications are allowed.')
                          : tr('Notifications are off for Hishab.'),
                      key: const ValueKey('alerts-status-text'),
                    ),
                  ),
                  if (_allowed == false)
                    FilledButton.tonal(
                      key: const ValueKey('alerts-allow'),
                      onPressed: _allow,
                      child: Text(tr('Allow')),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              tr(
                'Choose what each alert plays. Funny is its own silly sound, '
                "Phone's is your usual notification sound, and Silent only "
                'shows it in the notification shade.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final kind in AlertKind.values)
            _KindRow(
              kind: kind,
              mode: effectiveSound(
                kind,
                funSounds: funSounds,
                overrides: overrides,
              ),
              chosen: overrides.containsKey(kind),
              onMode: (mode) =>
                  setAlertSound(ProviderScope.containerOf(context), kind, mode),
              onTest: () => _test(kind),
            ),
          if (overrides.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('alerts-reset'),
                onPressed: () async {
                  final container = ProviderScope.containerOf(context);
                  for (final kind in overrides.keys) {
                    await setAlertSound(container, kind, null);
                  }
                },
                icon: const Icon(Icons.restart_alt),
                label: Text(tr('Use the general choice for all')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tr(
                'No sound at all? Check that the phone is not on silent or '
                'Do not disturb, and that Hishab is not muted under Apps > '
                'Hishab > Notifications in the phone settings.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindRow extends StatelessWidget {
  const _KindRow({
    required this.kind,
    required this.mode,
    required this.chosen,
    required this.onMode,
    required this.onTest,
  });

  final AlertKind kind;
  final AlertSoundMode mode;

  /// The person chose this one, rather than the general choice counting.
  final bool chosen;
  final ValueChanged<AlertSoundMode> onMode;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kind.label, style: theme.textTheme.titleSmall),
              ),
              IconButton(
                key: ValueKey('alert-test-${kind.channelId}'),
                tooltip: tr('Hear it'),
                icon: const Icon(Icons.play_circle_outline),
                onPressed: onTest,
              ),
            ],
          ),
          SegmentedButton<AlertSoundMode>(
            key: ValueKey('alert-mode-${kind.channelId}'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                value: AlertSoundMode.funny,
                label: Text(tr('Funny')),
              ),
              ButtonSegment(
                value: AlertSoundMode.phone,
                label: Text(tr("Phone's")),
              ),
              ButtonSegment(
                value: AlertSoundMode.silent,
                label: Text(tr('Silent')),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onMode(selection.first),
          ),
        ],
      ),
    );
  }
}
