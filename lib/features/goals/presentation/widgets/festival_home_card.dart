import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:hishab/features/goals/domain/festival_settings.dart';
import 'package:hishab/features/goals/presentation/providers/goals_providers.dart';
import 'package:hishab/features/goals/presentation/widgets/festival_tile.dart';

/// On Home: the nearest festival, once it is within
/// [festivalWindowDays] days, with its fund or a way to start one.
class FestivalHomeCard extends ConsumerWidget {
  const FestivalHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider)();
    final goals = ref.watch(goalsProvider).value ?? const [];
    final settings =
        ref.watch(festivalSettingsProvider).value ?? const FestivalSettings();
    final festivals = upcomingFestivals(today, goals, settings: settings);
    // Every festival may be hidden.
    if (festivals.isEmpty) return const SizedBox.shrink();
    final next = festivals.first;
    if (next.daysLeft > festivalWindowDays) return const SizedBox.shrink();
    return FestivalTile(
      item: next,
      today: today,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    );
  }
}
