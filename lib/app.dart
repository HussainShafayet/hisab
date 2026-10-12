import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_router.dart';
import 'package:hishab/core/theme/app_theme.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

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
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(recurringSyncProvider),
  );

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Adds what is due for the recurring items that add themselves, and sets
    // their reminders. Kept alive here for as long as the app runs.
    ref.watch(recurringSyncProvider);
    final preferences = ref.watch(preferencesProvider);
    // Set before anything below is built, so every `tr` already answers in
    // the chosen language.
    setAppLanguage(preferences.language);

    return MaterialApp.router(
      // Texts are looked up while building, not through the context, so a new
      // language needs the whole tree to be built again. A new key does that.
      key: ValueKey(preferences.language),
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
    );
  }
}
