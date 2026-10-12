import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:intl/intl.dart';

/// "Owes you" or "You owe".
String debtDirectionText(DebtDirection direction) =>
    direction == DebtDirection.lent ? tr('Owes you') : tr('You owe');

/// "Due 15 Oct", "Due today", "3 days late", "All paid", or null.
String? debtDueText(DebtItem item, DateTime today) {
  if (item.isSettled) return tr('All paid');
  final days = item.daysUntilDue(today);
  if (days == null) return null;
  if (days < 0) {
    return days == -1
        ? tr('1 day late')
        : tr('{days} days late', {'days': -days});
  }
  if (days == 0) return tr('Due today');
  return tr('Due {date}', {
    'date': DateFormat('d MMM').format(item.debt.dueOn!),
  });
}

/// One loan in the list: the person, what is left, and how far it is paid.
/// With [showPerson] off (a list of one person's loans) the title is the day
/// it was given instead of the name.
class DebtTile extends StatelessWidget {
  const DebtTile({
    required this.item,
    required this.today,
    required this.onTap,
    this.onLongPress,
    this.showPerson = true,
    super.key,
  });

  final DebtItem item;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showPerson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final lent = item.debt.direction == DebtDirection.lent;
    final amountColor = item.isSettled
        ? theme.colorScheme.onSurfaceVariant
        : (lent ? colors.income : colors.expense);
    final due = debtDueText(item, today);
    final late = item.isOverdue(today);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: amountColor.withValues(alpha: 0.15),
                    foregroundColor: amountColor,
                    child: Icon(lent ? Icons.call_made : Icons.call_received),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showPerson
                              ? item.debt.person
                              : (lent
                                    ? tr('Lent on {date}', {
                                        'date': DateFormat('d MMM yyyy')
                                            .format(item.debt.openedOn),
                                      })
                                    : tr('Borrowed on {date}', {
                                        'date': DateFormat('d MMM yyyy')
                                            .format(item.debt.openedOn),
                                      })),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          showPerson || item.debt.note.isEmpty
                              ? debtDirectionText(item.debt.direction)
                              : item.debt.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatPoisha(
                          item.isSettled ? item.debt.amount : item.remaining,
                        ),
                        key: ValueKey('debt-amount-${item.debt.id}'),
                        style: theme.textTheme.titleLarge?.tabular.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w600,
                          decoration: item.isSettled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 6,
                  color: amountColor,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Paid {paid} of {total}', {
                        'paid': formatPoisha(item.paid),
                        'total': formatPoisha(item.debt.amount),
                      }),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (due != null)
                    Text(
                      due,
                      key: ValueKey('debt-due-${item.debt.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: late
                            ? colors.expense
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: late ? FontWeight.w600 : null,
                      ),
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
