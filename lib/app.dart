import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/alert_route.dart';
import 'package:hishab/core/router/app_router.dart';
import 'package:hishab/core/theme/app_theme.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/reminders/alert_watcher.dart';
import 'package:hishab/features/reminders/reminder_sync.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';

/// Root widget. A [ConsumerStatefulWidget] is a StatefulWidget that has a
/// `ref` for reading Riverpod providers, like a component using hooks.
class HishabApp extends ConsumerStatefulWidget {
  const HishabApp({super.key});

  @override
  ConsumerState<HishabApp> createState() => _HishabAppState();
}

class _HishabAppState extends ConsumerState<HishabApp> {
  /// When the app comes back to the front, a new day may have started, so
  /// what is due is worked out again.
  late final AppLifecycleListener _lifecycle;

  /// Whether something changed since the automatic backup last wrote its file.
  /// True at the start, so the first time the app is left it writes one.
  bool _changed = true;
  bool _backingUp = false;

  /// When the app is left, a copy of the data goes to Downloads/Hishab (see
  /// docs/specs/backup/auto-backup.md), if it is on and something changed.
  Future<void> _saveAutoBackup() async {
    if (!_changed || _backingUp || !mounted) return;
    if (!ref.read(preferencesProvider).autoBackup) return;
    _backingUp = true;
    _changed = false;
    try {
      final saved = await ref
          .read(autoBackupServiceProvider)
          .run(ref.read(clockProvider)());
      // A problem, or nothing to save yet: try again the next time.
      if (!saved) _changed = true;
    } finally {
      _backingUp = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Made here, not where it is declared: a `late` field with a value is only
    // made when it is first used, and nothing uses it until the app ends.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(reminderSyncProvider),
      onPause: _saveAutoBackup,
    );
    // A tap on a notification on the phone opens the screen it is about.
    pendingNotificationRoute.addListener(_openTappedNotification);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openTappedNotification(),
    );
  }

  void _openTappedNotification() {
    final route = pendingNotificationRoute.value;
    if (route == null || !mounted) return;
    pendingNotificationRoute.value = null;
    openRouteWith(ref.read(routerProvider), route);
  }

  @override
  void dispose() {
    pendingNotificationRoute.removeListener(_openTappedNotification);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Adds what is due for the recurring items that add themselves, and sets
    // their reminders. Kept alive here for as long as the app runs.
    ref.watch(reminderSyncProvider);
    // Funny alerts for the budget and for habits, when an expense is written.
    ref.watch(alertWatcherProvider);
    // Entries, accounts, categories and budgets changing means a new copy.
    ref.listen(dataChangesProvider, (_, _) => _changed = true);
    final preferences = ref.watch(preferencesProvider);
    // Set before anything below is built, so every `tr` already answers in
    // the chosen language.
    setAppLanguage(preferences.language);

    return MaterialApp.router(
      // Texts are looked up while building, not through the context, so a new
      // language needs the whole tree to be built again. A new key does that.
      key: ValueKey(preferences.language),
      scaffoldMessengerKey: ref.watch(rootMessengerKeyProvider),
      onGenerateTitle: (_) => tr('Hishab'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (preferences.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      locale: preferences.language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      // The standard texts of Flutter's own widgets (date pickers, "OK",
      // "Cancel", the text selection menu) in both languages.
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      // The letters get bigger or smaller on top of the phone's own setting.
      builder: (context, child) {
        final scale = preferences.textSize.scale;
        if (scale == 1.0 || child == null) return child ?? const SizedBox();
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.textScaler.scale(1) * scale),
          ),
          child: child,
        );
      },
    );
  }
}
