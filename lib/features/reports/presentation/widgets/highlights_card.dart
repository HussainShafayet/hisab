import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/reports/domain/report_highlights.dart';
import 'package:hishab/features/reports/presentation/report_links.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:intl/intl.dart';

/// Facts about how the money was spent: the biggest day, days with no
/// spending, the average expense and which weekday takes most.
class HighlightsCard extends ConsumerWidget {
  const HighlightsCard({required this.range, super.key});

  final DateRange range;

  /// Short names of the weekdays, Sunday first (a Sunday and the six after it).
  static List<String> weekdayNames() => [
    for (var i = 0; i < 7; i++)
      DateFormat('E').format(DateTime(2026, 10, 4 + i)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(transactionsInRangeProvider(range)).value;
    if (items == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    final facts = highlightsOf(items, range: range, now: now);
    if (facts.expenseCount == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.financeColors;
    final names = weekdayNames();
    final busiest = facts.busiestWeekday;
    final top = facts.byWeekday.fold<int>(0, (a, b) => a > b ? a : b);

    Widget tile({
      required Key key,
      required IconData icon,
      required String label,
      required String value,
      VoidCallback? onTap,
    }) => InkWell(
      key: key,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.tabular.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    final biggestDay = facts.biggestDay;
    return Card(
      key: const ValueKey('report-highlights'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Highlights'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (biggestDay != null)
                  tile(
                    key: const ValueKey('highlight-day'),
                    icon: Icons.local_fire_department_outlined,
                    label: tr('Biggest spending day'),
                    value:
                        '${localizeDigits(DateFormat('E d MMM').format(biggestDay))}\n'
                        '${formatPoisha(facts.biggestDayTotal)}',
                    onTap: () => ReportLinks.day(
                      context,
                      title: localizeDigits(
                        DateFormat('EEEE d MMM').format(biggestDay),
                      ),
                      day: biggestDay,
                    ),
                  ),
                tile(
                  key: const ValueKey('highlight-nospend'),
                  icon: Icons.savings_outlined,
                  label: tr('Days with no spending'),
                  value: tr('{days} of {total}', {
                    'days': facts.noSpendDays,
                    'total': facts.daysInPeriod,
                  }),
                ),
                tile(
                  key: const ValueKey('highlight-average'),
                  icon: Icons.functions,
                  label: tr('Average expense'),
                  value: formatPoisha(facts.averageExpense),
                ),
                if (busiest != null)
                  tile(
                    key: const ValueKey('highlight-weekday'),
                    icon: Icons.calendar_view_week_outlined,
                    label: tr('Busiest weekday'),
                    value: names[busiest],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(tr('Spending by weekday'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: top == 0
                                    ? 0.02
                                    : (facts.byWeekday[i] / top).clamp(
                                        0.02,
                                        1.0,
                                      ),
                                child: Container(
                                  key: ValueKey('weekday-bar-$i'),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == busiest
                                        ? colors.expense
                                        : colors.expense.withValues(
                                            alpha: 0.35,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(names[i], style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
