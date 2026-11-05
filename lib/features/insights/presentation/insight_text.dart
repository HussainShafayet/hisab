import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:intl/intl.dart';

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
    case InsightKind.noSpendDays:
      return plural(
        args['count']! as int,
        'You had 1 day with no spending this month.',
        'You had {n} days with no spending this month.',
      );
    case InsightKind.busyWeekday:
      return tr('{percent}% of your spending is on {day}s.', {
        'percent': args['percent']!,
        'day': weekdayName(args['weekday']! as int),
      });
    case InsightKind.biggestExpense:
      return tr('{amount} on {label} is your biggest expense this month.', {
        'amount': money('amount'),
        'label': args['label']!,
      });
    case InsightKind.savingsKept:
      return tr('You have kept {percent}% of your income so far.', args);
    case InsightKind.spentMoreThanEarned:
      return tr('You have spent {amount} more than you earned this month.', {
        'amount': money('amount'),
      });
    case InsightKind.smallSpends:
      return tr('{count} small expenses under ৳100 added up to {amount}.', {
        'count': args['count']!,
        'amount': money('amount'),
      });
    case InsightKind.regretShare:
      return tr('{percent}% of this month\'s spending is marked Regret.', args);
    case InsightKind.loanToGet:
    case InsightKind.loanToPay:
      final days = args['days']! as int;
      final texts = {
        'person': args['person']!,
        'amount': money('amount'),
        'days': days,
      };
      final get = insight.kind == InsightKind.loanToGet;
      return switch (days) {
        0 =>
          get
              ? tr('{person} should pay you {amount} today.', texts)
              : tr('You should pay {person} {amount} today.', texts),
        1 =>
          get
              ? tr('{person} should pay you {amount} tomorrow.', texts)
              : tr('You should pay {person} {amount} tomorrow.', texts),
        _ =>
          get
              ? tr('{person} should pay you {amount} in {days} days.', texts)
              : tr('You should pay {person} {amount} in {days} days.', texts),
      };
  }
}

/// The name of a weekday, 0 being Sunday.
String weekdayName(int weekday) =>
    DateFormat('EEEE').format(DateTime(2026, 10, 4 + weekday));

IconData insightIcon(InsightKind kind) => switch (kind) {
  InsightKind.spendingUp => Icons.trending_up,
  InsightKind.spendingDown => Icons.trending_down,
  InsightKind.overBudgetPace => Icons.speed,
  InsightKind.withinBudgetPace => Icons.check_circle_outline,
  InsightKind.categoryJump => Icons.arrow_upward,
  InsightKind.topCategory => Icons.pie_chart_outline,
  InsightKind.recurringSoon => Icons.event,
  InsightKind.noSpendDays => Icons.savings_outlined,
  InsightKind.busyWeekday => Icons.calendar_view_week_outlined,
  InsightKind.biggestExpense => Icons.local_fire_department_outlined,
  InsightKind.savingsKept => Icons.emoji_events_outlined,
  InsightKind.spentMoreThanEarned => Icons.warning_amber_outlined,
  InsightKind.smallSpends => Icons.coffee_outlined,
  InsightKind.regretShare => Icons.sentiment_dissatisfied_outlined,
  InsightKind.loanToGet => Icons.south_west,
  InsightKind.loanToPay => Icons.north_east,
};

Color insightColor(BuildContext context, InsightTone tone) {
  final colors = context.financeColors;
  return switch (tone) {
    InsightTone.warning => colors.warning,
    InsightTone.good => colors.income,
    InsightTone.info => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}
