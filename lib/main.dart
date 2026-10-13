import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/app.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  // Open now so the schema is created and seeded on first launch, and a
  // migration error shows up at startup instead of on the first screen.
  await database.doWhenOpened((_) {});

  // The saved language and theme are read before the first frame, so the app
  // does not start in English and then switch.
  final preferences = await SettingsRepository(database).load();
  setAppLanguage(preferences.language);
  // Month and day names for both languages.
  await initializeDateFormatting('en');
  await initializeDateFormatting('bn');

  // The container holds the state of every Riverpod provider.
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      initialPreferencesProvider.overrideWithValue(preferences),
      reminderSchedulerProvider.overrideWithValue(PluginReminderScheduler()),
    ],
  );

  // An error that nothing caught (a failed save in a button's handler, say)
  // would only reach the log. Say so on screen, in plain words, as well.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    container
        .read(rootMessengerKeyProvider)
        .currentState
        ?.showError(describeError(error));
    return true;
  };

  runApp(
    UncontrolledProviderScope(container: container, child: const HishabApp()),
  );
}
