import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/router/app_router.dart';
import 'package:hishab/core/theme/app_theme.dart';

/// Root widget. A [ConsumerWidget] is a StatelessWidget that receives a `ref`
/// for reading Riverpod providers, like a component using a hook.
class HishabApp extends ConsumerWidget {
  const HishabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Hishab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
