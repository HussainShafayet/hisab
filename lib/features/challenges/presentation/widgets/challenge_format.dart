import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';

/// "3 days to go", or "Last day".
String challengeDaysToGo(ChallengeItem item, DateTime today) {
  final left = item.daysLeft(today);
  return left <= 1 ? tr('Last day') : tr('{n} days to go', {'n': left});
}

/// One line on where a challenge stands.
String challengeStatusLine(ChallengeItem item, DateTime today) {
  final challenge = item.challenge;
  final noSpend = challenge.kind == ChallengeKind.noSpend;
  switch (item.stateOn(today)) {
    case ChallengeState.upcoming:
      final days = item.daysUntilStart(today);
      return days == 1
          ? tr('Starts tomorrow')
          : tr('Starts in {n} days', {'n': days});
    case ChallengeState.active:
      final first = noSpend
          ? tr('Day {day} of {total}', {
              'day': item.dayNumber(today),
              'total': challenge.days,
            })
          : tr('{amount} left to spend', {
              'amount': formatPoisha(item.remaining),
            });
      return '$first · ${challengeDaysToGo(item, today)}';
    case ChallengeState.won:
      return noSpend
          ? tr('Completed: nothing spent!')
          : tr('Completed: you stayed within the limit.');
    case ChallengeState.broken:
      return noSpend
          ? tr('Broken: {amount} spent', {'amount': formatPoisha(item.spent)})
          : tr('{amount} over the limit', {
              'amount': formatPoisha(item.spent - challenge.limit),
            });
  }
}

IconData challengeIcon(ChallengeState state) => switch (state) {
  ChallengeState.upcoming => Icons.schedule,
  ChallengeState.active => Icons.timer_outlined,
  ChallengeState.won => Icons.emoji_events,
  ChallengeState.broken => Icons.sentiment_dissatisfied_outlined,
};

Color challengeColor(BuildContext context, ChallengeState state) {
  final colors = context.financeColors;
  return switch (state) {
    ChallengeState.upcoming => Theme.of(context).colorScheme.onSurfaceVariant,
    ChallengeState.active => Theme.of(context).colorScheme.primary,
    ChallengeState.won => colors.income,
    ChallengeState.broken => colors.expense,
  };
}

/// How full the bar of a challenge is: the part of the limit used, and for a
/// no-spend challenge the part of its days gone.
double challengeBarValue(ChallengeItem item, DateTime today) {
  final state = item.stateOn(today);
  if (state == ChallengeState.broken) return 1;
  if (state == ChallengeState.won) return 1;
  if (state == ChallengeState.upcoming) return 0;
  if (item.challenge.kind == ChallengeKind.limit) return item.fraction;
  return item.dayNumber(today) / item.challenge.days;
}
