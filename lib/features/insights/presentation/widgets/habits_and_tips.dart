import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/insights/domain/habits.dart';
import 'package:hishab/features/insights/presentation/money_tips.dart';
import 'package:hishab/features/insights/presentation/providers/habits_providers.dart';
import 'package:hishab/features/reports/presentation/report_links.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// "Your habits": what is spent on again and again, and what it comes to in a
/// month. A tap lists the entries.
class HabitsCard extends ConsumerWidget {
  const HabitsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final now = ref.watch(clockProvider)();
    final today = dateOnly(now);
    final range = (
      start: today.subtract(const Duration(days: habitWindowDays - 1)),
      end: today.add(const Duration(days: 1)),
    );
    return Card(
      key: const ValueKey('habits-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.repeat, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(tr('Your habits'), style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            if (habits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(
                    'No habit yet. Something spent on 8 times in 30 days shows '
                    'up here.',
                  ),
                  key: const ValueKey('no-habits'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final habit in habits)
              InkWell(
                key: ValueKey('habit-${habit.categoryId}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => ReportLinks.category(
                  context,
                  ref,
                  categoryId: habit.categoryId,
                  name: habit.name,
                  range: range,
                  type: TransactionType.expense,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(habit.name, style: theme.textTheme.bodyLarge),
                            Text(
                              tr('{count} times in 30 days', {
                                'count': habit.count,
                              }),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPoisha(habit.total),
                            style: theme.textTheme.titleSmall?.tabular.copyWith(
                              color: colors.expense,
                            ),
                          ),
                          Text(
                            tr('about {amount} a month', {
                              'amount': formatPoisha(habit.perMonth),
                            }),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One piece of money advice a day, with a button for the next one.
class TipCard extends ConsumerStatefulWidget {
  const TipCard({super.key});

  @override
  ConsumerState<TipCard> createState() => _TipCardState();
}

class _TipCardState extends ConsumerState<TipCard> {
  int _skip = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tip = tipOfTheDay(ref.watch(clockProvider)(), skip: _skip);
    return Card(
      key: const ValueKey('tip-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(tr('Tip of the day'), style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(tip, key: const ValueKey('tip-text')),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('tip-next'),
                onPressed: () => setState(() => _skip++),
                child: Text(tr('Another tip')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
