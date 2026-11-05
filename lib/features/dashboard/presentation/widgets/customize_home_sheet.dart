import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/dashboard/domain/home_layout.dart';
import 'package:hishab/features/dashboard/presentation/providers/home_layout_providers.dart';

/// What a part of Home is called in the sheet.
String homeSectionLabel(HomeSection section) => switch (section) {
  HomeSection.shortcuts => tr('Quick buttons'),
  HomeSection.safeToSpend => tr('Safe to spend today'),
  HomeSection.plans => tr('Plans and loans'),
  HomeSection.topSpending => tr('Top spending'),
  HomeSection.recent => tr('Recent'),
  HomeSection.extras => tr('Takka, streak and insights'),
};

/// Lets the person choose which parts of Home are shown.
Future<void> showCustomizeHome(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _CustomizeHomeSheet(),
    );

class _CustomizeHomeSheet extends ConsumerWidget {
  const _CustomizeHomeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(homeHiddenProvider).value ?? const <HomeSection>{};
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                tr('Choose what Home shows'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final section in HomeSection.values)
              SwitchListTile(
                key: ValueKey('home-section-${section.name}'),
                title: Text(homeSectionLabel(section)),
                value: !hidden.contains(section),
                onChanged: (on) => setHomeSectionHidden(
                  ProviderScope.containerOf(context),
                  section,
                  away: !on,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
