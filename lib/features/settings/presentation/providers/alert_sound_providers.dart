import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_sound_mode.dart';

/// The sounds the person chose for single alerts, kept up to date.
final alertSoundOverridesProvider =
    StreamProvider<Map<AlertKind, AlertSoundMode>>(
      (ref) => ref
          .watch(appDatabaseProvider)
          .settingsDao
          .watchAll()
          .map(alertSoundOverrides),
    );

/// Chooses the sound of [kind], or goes back to the general choice with null.
Future<void> setAlertSound(
  ProviderContainer container,
  AlertKind kind,
  AlertSoundMode? mode,
) => container
    .read(appDatabaseProvider)
    .settingsDao
    .put(alertSoundKey(kind), mode?.name);
