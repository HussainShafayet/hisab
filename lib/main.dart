import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/app.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/database/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  // Open now so the schema is created and seeded on first launch, and a
  // migration error shows up at startup instead of on the first screen.
  await database.doWhenOpened((_) {});

  // ProviderScope holds the state of every Riverpod provider.
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const HishabApp(),
    ),
  );
}
