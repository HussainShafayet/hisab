import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/zakat/data/zakat_settings_repository.dart';

final zakatSettingsRepositoryProvider = Provider<ZakatSettingsRepository>(
  (ref) => ZakatSettingsRepository(ref.watch(appDatabaseProvider)),
);

/// What is remembered for the zakat calculator, again after every change.
final zakatSettingsProvider = StreamProvider<ZakatSettings>(
  (ref) => ref.watch(zakatSettingsRepositoryProvider).watch(),
);
