import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

/// The preferences saved before the app started. `main()` reads them first,
/// so the very first frame is already in the right language and theme.
/// Without an override (tests) these are the defaults.
final initialPreferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences.defaults,
);

/// The preferences as they are saved, again after every change.
final preferencesStreamProvider = StreamProvider<AppPreferences>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// The preferences to use right now: the saved ones, or what `main()` read
/// until the first saved value arrives.
final preferencesProvider = Provider<AppPreferences>(
  (ref) =>
      ref.watch(preferencesStreamProvider).value ??
      ref.watch(initialPreferencesProvider),
);
