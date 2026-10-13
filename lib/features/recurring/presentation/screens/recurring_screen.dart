import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/recurring/presentation/widgets/due_recurring_card.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:intl/intl.dart';

/// "Every month" and so on.
String frequencyText(RecurrenceFrequency frequency) => switch (frequency) {
  RecurrenceFrequency.weekly => tr('Every week'),
  RecurrenceFrequency.monthly => tr('Every month'),
  RecurrenceFrequency.yearly => tr('Every year'),
};

enum _RuleAction { pause, resume, delete }

/// The things that repeat, like rent and a salary: what is due, and all of
/// them.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    RecurringRule rule,
    _RuleAction action,
  ) async {
    final repository = ref.read(recurringRepositoryProvider);
    switch (action) {
      case _RuleAction.pause:
        await repository.setPaused(rule.id, paused: true);
      case _RuleAction.resume:
        await repository.setPaused(rule.id, paused: false);
      case _RuleAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Delete "{name}"?', {'name': rule.title})),
            content: Text(
              tr(
                'It will not come round again. Transactions it already made '
                'are kept.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(tr('Delete')),
              ),
            ],
          ),
        );
        if (ok == true) await repository.deleteRule(rule.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);
    final theme = Theme.of(context);
    final colors = context.financeColors;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Recurring'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newRecurring),
        icon: const Icon(Icons.add),
        label: Text(tr('Add recurring')),
      ),
      body: rules.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.repeat,
              title: tr('Nothing repeats yet'),
              message: tr(
                'Add rent, bills or a salary once, and Hishab reminds you or '
                'adds them for you.',
              ),
              action: FilledButton(
                onPressed: () => context.push(AppRoutes.newRecurring),
                child: Text(tr('Add recurring')),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const DueRecurringCard(),
              for (final rule in list)
                ListTile(
                  key: ValueKey('rule-${rule.id}'),
                  onTap: () => context.push(AppRoutes.editRecurring(rule.id)),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.repeat,
                      color: rule.type == TransactionType.income
                          ? colors.income
                          : colors.expense,
                    ),
                  ),
                  title: Text(
                    rule.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_subtitle(rule), maxLines: 2),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.3,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatPoisha(rule.amount),
                            style: theme.textTheme.titleSmall?.tabular.copyWith(
                              color: rule.type == TransactionType.income
                                  ? colors.income
                                  : colors.expense,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<_RuleAction>(
                        key: ValueKey('menu-${rule.id}'),
                        onSelected: (action) =>
                            _onAction(context, ref, rule, action),
                        itemBuilder: (context) => [
                          if (rule.isPaused)
                            PopupMenuItem(
                              value: _RuleAction.resume,
                              child: Text(tr('Resume')),
                            )
                          else
                            PopupMenuItem(
                              value: _RuleAction.pause,
                              child: Text(tr('Pause')),
                            ),
                          PopupMenuItem(
                            value: _RuleAction.delete,
                            child: Text(tr('Delete')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// "Every month · next 5 Nov · adds itself", or why it is not coming.
  String _subtitle(RecurringRule rule) {
    final parts = [
      frequencyText(rule.frequency),
      if (rule.isPaused)
        tr('Paused')
      else if (rule.isFinished)
        tr('Ended')
      else
        tr('Next {date}', {'date': DateFormat('d MMM').format(rule.nextDue)}),
      if (rule.autoAdd) tr('Adds itself'),
    ];
    return parts.join(' · ');
  }
}
