import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:intl/intl.dart';

/// The recurring items that are due and waiting: each can be added as a
/// transaction or skipped. Shows nothing when none is waiting.
class DueRecurringCard extends ConsumerWidget {
  const DueRecurringCard({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showMessage(done);
    } on Object catch (e) {
      messenger.showError(describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(dueItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final repository = ref.read(recurringRepositoryProvider);
    final today = ref.read(clockProvider)();

    return Card(
      key: const ValueKey('due-recurring'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_available,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('Due now'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            for (final item in items) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.rule.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          item.more == 0
                              ? tr('Due on {date}', {
                                  'date': DateFormat('d MMM').format(item.due),
                                })
                              : tr('Due on {date}, and {count} more', {
                                  'date': DateFormat('d MMM').format(item.due),
                                  'count': item.more,
                                }),
                          key: ValueKey('due-text-${item.rule.id}'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatPoisha(item.rule.amount),
                    style: theme.textTheme.titleMedium?.tabular.copyWith(
                      color: item.rule.type == TransactionType.income
                          ? colors.income
                          : colors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: ValueKey('skip-${item.rule.id}'),
                    onPressed: () => _run(
                      context,
                      () => repository.skipDue(item.rule.id, today),
                      tr('Skipped {title}.', {'title': item.rule.title}),
                    ),
                    child: Text(tr('Skip')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: ValueKey('add-due-${item.rule.id}'),
                    onPressed: () => _run(
                      context,
                      () => repository.addDue(item.rule.id, today),
                      tr('Added {title}.', {'title': item.rule.title}),
                    ),
                    child: Text(tr('Add')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
