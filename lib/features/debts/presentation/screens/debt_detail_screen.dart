import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/debt_tile.dart';
import 'package:hishab/features/debts/presentation/widgets/debt_actions.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_share.dart';
import 'package:intl/intl.dart';

/// One loan: what is left, the payments so far, and a way to add one.
class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({required this.debtId, super.key});

  final int debtId;

  Future<void> _deletePayment(
    BuildContext context,
    WidgetRef ref,
    DebtPayment payment,
  ) async {
    final ok = await confirmLoanAction(
      context,
      title: tr('Delete this payment?'),
      body: tr('The amount goes back to what is left.'),
      action: tr('Delete'),
    );
    if (!ok || !context.mounted) return;
    await ref.read(debtsRepositoryProvider).deletePayment(payment.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(debtProvider(debtId));
    final payments =
        ref.watch(debtPaymentsProvider(debtId)).value ?? const <DebtPayment>[];
    final today = ref.read(clockProvider)();

    return item.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: '$error'),
      ),
      data: (debt) {
        if (debt == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(message: tr('This loan no longer exists.')),
          );
        }
        final theme = Theme.of(context);
        final colors = context.financeColors;
        final lent = debt.debt.direction == DebtDirection.lent;
        final color = debt.isSettled
            ? theme.colorScheme.onSurfaceVariant
            : (lent ? colors.income : colors.expense);
        final due = debtDueText(debt, today);
        final sameName = (ref.watch(debtsProvider).value ?? const <DebtItem>[])
            .where(
              (i) => personKey(i.debt.person) == personKey(debt.debt.person),
            )
            .length;

        return Scaffold(
          appBar: AppBar(
            title: Text(debt.debt.person),
            actions: [
              IconButton(
                key: const ValueKey('edit-loan'),
                tooltip: tr('Edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push(AppRoutes.editDebt(debt.debt.id)),
              ),
              IconButton(
                key: const ValueKey('delete-loan'),
                tooltip: tr('Delete'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await deleteLoan(context, ref, debt) && context.mounted) {
                    context.pop();
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debtDirectionText(debt.debt.direction),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatPoisha(debt.remaining),
                          key: const ValueKey('remaining'),
                          style: theme.textTheme.displaySmall?.tabular.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        lent ? tr('left to get back') : tr('left to pay back'),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: debt.progress,
                          minHeight: 8,
                          color: color,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('Paid {paid} of {total}', {
                          'paid': formatPoisha(debt.paid),
                          'total': formatPoisha(debt.debt.amount),
                        }),
                        key: const ValueKey('paid-of-total'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (lent ? tr('Lent on {date}') : tr('Borrowed on {date}'))
                            .replaceAll(
                              '{date}',
                              DateFormat('d MMM yyyy')
                                  .format(debt.debt.openedOn),
                            ),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (due != null)
                        Text(
                          due,
                          key: const ValueKey('due-text'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: debt.isOverdue(today)
                                ? colors.expense
                                : null,
                          ),
                        ),
                      if (debt.debt.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(debt.debt.note),
                      ],
                    ],
                  ),
                ),
              ),
              if (!debt.isSettled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('add-payment'),
                        onPressed: () => addLoanPayment(context, debt),
                        icon: const Icon(Icons.add),
                        label: Text(tr('Add a payment')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('mark-paid'),
                        onPressed: () => markLoanPaid(context, ref, debt),
                        icon: const Icon(Icons.done_all),
                        label: Text(tr('All paid')),
                      ),
                    ),
                  ],
                ),
                if (lent) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('remind'),
                    onPressed: () => shareLoanReminder(
                      context,
                      ref,
                      name: debt.debt.person,
                      amount: debt.remaining,
                      dueOn: debt.debt.dueOn,
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(tr('Send a reminder')),
                  ),
                ],
              ],
              if (sameName > 1)
                TextButton.icon(
                  key: const ValueKey('see-person'),
                  onPressed: () =>
                      context.push(AppRoutes.debtPerson(debt.debt.person)),
                  icon: const Icon(Icons.people_outline),
                  label: Text(
                    tr('Everything with {name}', {'name': debt.debt.person}),
                  ),
                ),
              const SizedBox(height: 20),
              Text(tr('Payments'), style: theme.textTheme.titleSmall),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    tr('No payments yet.'),
                    key: const ValueKey('no-payments'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final payment in payments)
                ListTile(
                  key: ValueKey('payment-${payment.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatPoisha(payment.amount)),
                  subtitle: Text(
                    [
                      DateFormat('d MMM yyyy').format(payment.paidOn),
                      if (payment.note.isNotEmpty) payment.note,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    key: ValueKey('delete-payment-${payment.id}'),
                    tooltip: tr('Delete'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deletePayment(context, ref, payment),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
