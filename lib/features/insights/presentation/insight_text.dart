import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/insights/domain/insights.dart';

/// The sentence for [insight], in the language of the app.
String insightText(Insight insight) {
  final args = insight.args;
  String money(String key) => formatPoisha(args[key]! as int);

  switch (insight.kind) {
    case InsightKind.spendingUp:
      return tr(
        'You spent {percent}% more than the same days last month.',
        args,
      );
    case InsightKind.spendingDown:
      return tr(
        'You spent {percent}% less than the same days last month.',
        args,
      );
    case InsightKind.overBudgetPace:
      return tr(
        'At this pace you will spend {projected} this month, over your {limit} budget.',
        {'projected': money('projected'), 'limit': money('limit')},
      );
    case InsightKind.withinBudgetPace:
      return tr(
        'At this pace you will spend {projected} this month, within your {limit} budget.',
        {'projected': money('projected'), 'limit': money('limit')},
      );
    case InsightKind.categoryJump:
      return tr('{name} is up {amount} on the same days last month.', {
        'name': args['name']!,
        'amount': money('amount'),
      });
    case InsightKind.topCategory:
      return tr("{name} is {percent}% of this month's spending.", args);
    case InsightKind.recurringSoon:
      final days = args['days']! as int;
      return switch (days) {
        0 => tr('{title} is due today.', args),
        1 => tr('{title} is due tomorrow.', args),
        _ => tr('{title} is due in {days} days.', args),
      };
  }
}

IconData insightIcon(InsightKind kind) => switch (kind) {
  InsightKind.spendingUp => Icons.trending_up,
  InsightKind.spendingDown => Icons.trending_down,
  InsightKind.overBudgetPace => Icons.speed,
  InsightKind.withinBudgetPace => Icons.check_circle_outline,
  InsightKind.categoryJump => Icons.arrow_upward,
  InsightKind.topCategory => Icons.pie_chart_outline,
  InsightKind.recurringSoon => Icons.event,
};

Color insightColor(BuildContext context, InsightTone tone) {
  final colors = context.financeColors;
  return switch (tone) {
    InsightTone.warning => colors.warning,
    InsightTone.good => colors.income,
    InsightTone.info => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}
