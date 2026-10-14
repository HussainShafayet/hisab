import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:intl/intl.dart';

/// A coming festival: how many days are left and, below, either how far its
/// fund has come (a tap opens it) or a button to start one.
class FestivalTile extends StatelessWidget {
  const FestivalTile({
    required this.item,
    required this.today,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 10),
    super.key,
  });

  final UpcomingFestival item;
  final DateTime today;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fund = item.fund;
    final isEid = item.festival != Festival.pohelaBoishakh;
    final date = DateFormat.MMMd().format(item.date);
    final when = isEstimated(item.festival)
        ? tr('About {date}', {'date': date})
        : date;
    final days = item.daysLeft == 0
        ? festivalGreeting(item.festival)
        : tr('{n} days to go', {'n': item.daysLeft});

    return Card(
      key: ValueKey('festival-${item.festival.name}'),
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: fund == null
            ? null
            : () => context.push(AppRoutes.goal(fund.goal.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    foregroundColor: theme.colorScheme.onTertiaryContainer,
                    child: Icon(isEid ? Icons.mosque : Icons.celebration),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          festivalName(item.festival),
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          when,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    days,
                    key: ValueKey('festival-days-${item.festival.name}'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (fund != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fund.fraction,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('{saved} of {target}', {
                    'saved': formatPoisha(fund.saved),
                    'target': formatPoisha(fund.goal.target),
                  }),
                  style: theme.textTheme.bodyMedium?.tabular,
                ),
                Text(
                  fund.isReached
                      ? tr('The fund is ready!')
                      : fund.perMonth(today) == null
                      ? tr('{amount} still to put aside', {
                          'amount': formatPoisha(fund.left),
                        })
                      : tr('Put aside {amount} a month', {
                          'amount': formatPoisha(fund.perMonth(today)!),
                        }),
                  key: ValueKey('festival-hint-${item.festival.name}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          'How much will you need for shopping, salami and '
                          'guests?',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      key: ValueKey('festival-start-${item.festival.name}'),
                      onPressed: () => context.push(
                        AppRoutes.newGoalFor(
                          name: festivalFundName(item.festival, item.date),
                          day: item.date,
                        ),
                      ),
                      child: Text(tr('Start a fund')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
