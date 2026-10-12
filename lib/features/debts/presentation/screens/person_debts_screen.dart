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
import 'package:hishab/features/debts/presentation/widgets/debt_actions.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_list_item.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_share.dart';

/// Every loan with one person, and what is left between the two of us.
class PersonDebtsScreen extends ConsumerWidget {
  const PersonDebtsScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);
    final today = ref.read(clockProvider)();
    final key = personKey(name);

    return debts.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: '$error'),
      ),
      data: (items) {
        final mine = items.where((i) => personKey(i.debt.person) == key);
        if (mine.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(name)),
            body: ErrorView(message: tr('No loans with this person.')),
          );
        }
        final person = groupByPerson(mine, today).single;
        return _PersonView(person: person, today: today);
      },
    );
  }
}

class _PersonView extends ConsumerWidget {
  const _PersonView({required this.person, required this.today});

  final PersonDebts person;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final net = person.net;

    final String headline;
    if (person.isSettled) {
      headline = tr('All paid');
    } else if (net > 0) {
      headline = tr('{name} owes you', {'name': person.name});
    } else if (net < 0) {
      headline = tr('You owe {name}', {'name': person.name});
    } else {
      headline = tr('You and {name} are even', {'name': person.name});
    }
    final color = person.isSettled || net == 0
        ? theme.colorScheme.onSurfaceVariant
        : (net > 0 ? colors.income : colors.expense);
    final bothWays = person.toReceive > 0 && person.toPay > 0;
    final open = person.items.where((i) => !i.isSettled).toList();
    final settled = person.items.where((i) => i.isSettled).toList();

    return Scaffold(
      appBar: AppBar(title: Text(person.name)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-loan-for-person'),
        onPressed: () => context.push(AppRoutes.newDebtFor(person.name)),
        icon: const Icon(Icons.add),
        label: Text(tr('Add loan')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: theme.textTheme.labelLarge),
                  if (!person.isSettled) ...[
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatPoisha(net.abs()),
                        key: const ValueKey('person-total'),
                        style: theme.textTheme.displaySmall?.tabular.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (bothWays) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('{name} owes you {get}, you owe {give}', {
                        'name': person.name,
                        'get': formatPoisha(person.toReceive),
                        'give': formatPoisha(person.toPay),
                      }),
                      key: const ValueKey('person-both-ways'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (person.setOffAmount > 0) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('set-off'),
                      onPressed: () => setOffWithPerson(context, ref, person),
                      icon: const Icon(Icons.compare_arrows),
                      label: Text(tr('Set off')),
                    ),
                  ],
                  if (net > 0) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('remind-person'),
                      onPressed: () => shareLoanReminder(
                        context,
                        ref,
                        name: person.name,
                        amount: net,
                        dueOn: _earliestDue(open),
                      ),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(tr('Send a reminder')),
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (final item in open)
            LoanListItem(item: item, today: today, showPerson: false),
          if (settled.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(tr('Paid'), style: theme.textTheme.titleSmall),
            ),
            for (final item in settled)
              LoanListItem(item: item, today: today, showPerson: false),
          ],
        ],
      ),
    );
  }

  /// The soonest due day among the loans the person still owes me.
  DateTime? _earliestDue(List<DebtItem> open) {
    final days = [
      for (final i in open)
        if (i.debt.direction == DebtDirection.lent && i.debt.dueOn != null)
          i.debt.dueOn!,
    ]..sort();
    return days.firstOrNull;
  }
}
