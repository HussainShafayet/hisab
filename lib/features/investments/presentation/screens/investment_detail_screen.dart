import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/presentation/providers/investments_providers.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_entry_dialog.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_format.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_summary.dart';
import 'package:intl/intl.dart';

enum _Menu { edit, close, reopen, delete }

/// One investment: how it is doing, the buttons to add money, and every line.
class InvestmentDetailScreen extends ConsumerWidget {
  const InvestmentDetailScreen({required this.investmentId, super.key});

  final int investmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(investmentsProvider);

    return items.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: describeError(error)),
      ),
      data: (list) {
        final item = list
            .where((i) => i.investment.id == investmentId)
            .firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(message: tr('Investment not found.')),
          );
        }
        return _Detail(item: item);
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.item});

  final InvestmentItem item;

  Future<void> _add(BuildContext context, InvestmentEntryKind kind) =>
      showInvestmentEntryDialog(context, item: item, kind: kind);

  Future<void> _onMenu(BuildContext context, WidgetRef ref, _Menu menu) async {
    final repository = ref.read(investmentsRepositoryProvider);
    final id = item.investment.id;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (menu) {
        case _Menu.edit:
          await context.push(AppRoutes.editInvestment(id));
        case _Menu.close:
          final ok = await _confirm(
            context,
            title: tr('Close "{name}"?', {'name': item.investment.name}),
            body: tr(
              'Closing means it is over. What you have not taken back counts '
              'as lost. You can still record profit and money taken back, '
              'and open it again any time.',
            ),
            action: tr('Close'),
          );
          if (ok) await repository.setClosed(id, closed: true);
        case _Menu.reopen:
          await repository.setClosed(id, closed: false);
        case _Menu.delete:
          final ok = await _confirm(
            context,
            title: tr('Delete "{name}"?', {'name': item.investment.name}),
            body: tr(
              'Its lines and every change they made to your accounts are '
              'removed. This cannot be undone.',
            ),
            action: tr('Delete'),
          );
          if (!ok) return;
          await repository.deleteInvestment(id);
          if (context.mounted) context.pop();
      }
    } on Object catch (e) {
      messenger.showError(describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final investment = item.investment;
    final entries =
        ref.watch(investmentEntriesProvider(investment.id)).value ??
        const <InvestmentEntry>[];
    final accounts = {
      for (final a in ref.watch(accountsProvider(true)).value ?? const [])
        a.account.id: a.account.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(investment.name),
        actions: [
          PopupMenuButton<_Menu>(
            key: const ValueKey('investment-menu'),
            onSelected: (menu) => _onMenu(context, ref, menu),
            itemBuilder: (context) => [
              PopupMenuItem(value: _Menu.edit, child: Text(tr('Edit'))),
              if (investment.isClosed)
                PopupMenuItem(
                  value: _Menu.reopen,
                  child: Text(tr('Open again')),
                )
              else
                PopupMenuItem(value: _Menu.close, child: Text(tr('Close'))),
              PopupMenuItem(value: _Menu.delete, child: Text(tr('Delete'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          if (investment.note.isNotEmpty || investment.isClosed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (investment.isClosed)
                    Chip(
                      key: const ValueKey('investment-closed'),
                      label: Text(tr('Closed')),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (investment.note.isNotEmpty)
                    Text(
                      investment.note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          InvestmentSummary(
            totalReturn: item.totalReturn,
            roiPercent: item.roiPercent,
            stats: [
              InvestmentStat(
                label: tr('Put in'),
                amount: item.putIn,
                key: 'investment-put-in',
              ),
              if (item.takenBack > 0)
                InvestmentStat(
                  label: tr('Taken back'),
                  amount: item.takenBack,
                  key: 'investment-taken-back',
                ),
              InvestmentStat(
                label: tr('Still in'),
                amount: item.stillIn,
                key: 'investment-still-in',
              ),
              InvestmentStat(
                label: tr('Profit received'),
                amount: item.profit,
                key: 'investment-profit',
              ),
              InvestmentStat(
                label: investment.currentValue == null
                    ? tr('Worth now (at cost)')
                    : tr('Worth now'),
                amount: item.value,
                key: 'investment-value',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('investment-add-put-in'),
                  onPressed: investment.isClosed
                      ? null
                      : () => _add(context, InvestmentEntryKind.putIn),
                  icon: const Icon(Icons.add),
                  label: Text(tr('Put money in')),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('investment-add-profit'),
                  onPressed: () => _add(context, InvestmentEntryKind.profit),
                  icon: const Icon(Icons.trending_up),
                  label: Text(tr('Got profit')),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('investment-add-take-back'),
                  onPressed: item.stillIn == 0
                      ? null
                      : () => _add(context, InvestmentEntryKind.takeBack),
                  icon: const Icon(Icons.undo),
                  label: Text(tr('Took money back')),
                ),
                if (!investment.isClosed)
                  OutlinedButton.icon(
                    key: const ValueKey('investment-set-value'),
                    onPressed: () =>
                        showInvestmentValueDialog(context, item: item),
                    icon: const Icon(Icons.price_change_outlined),
                    label: Text(tr('Update value')),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(tr('Lines'), style: theme.textTheme.titleSmall),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                tr(
                  'Nothing yet. Tap "Put money in" for the first taka you put '
                  'in.',
                ),
                key: const ValueKey('investment-no-lines'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final entry in entries)
              _EntryTile(
                key: ValueKey('investment-entry-${entry.id}'),
                entry: entry,
                accountName: accounts[entry.accountId],
              ),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.accountName, super.key});

  final InvestmentEntry entry;
  final String? accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final icon = switch (entry.kind) {
      InvestmentEntryKind.putIn => Icons.add_circle_outline,
      InvestmentEntryKind.profit => Icons.trending_up,
      InvestmentEntryKind.takeBack => Icons.undo,
    };
    final notes = [
      DateFormat('d MMM yyyy').format(entry.date),
      ?accountName,
      if (entry.note.isNotEmpty) entry.note,
    ];

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Row(
        children: [
          Expanded(child: Text(kindLabel(entry.kind))),
          Text(
            formatPoisha(entry.amount),
            key: ValueKey('investment-entry-amount-${entry.id}'),
            style: theme.textTheme.bodyLarge?.tabular,
          ),
        ],
      ),
      subtitle: Text(notes.join(' · ')),
      trailing: IconButton(
        key: ValueKey('investment-entry-delete-${entry.id}'),
        tooltip: tr('Delete'),
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _delete(context, ref),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      context,
      title: tr('Remove this line?'),
      body: entry.accountId == null
          ? tr('{amount} will no longer count.', {
              'amount': formatPoisha(entry.amount),
            })
          : tr(
              '{amount} will no longer count, and the change it made to the '
              'account is taken back.',
              {'amount': formatPoisha(entry.amount)},
            ),
      action: tr('Remove'),
      actionKey: const ValueKey('investment-confirm'),
    );
    if (!ok) return;
    try {
      await ref.read(investmentsRepositoryProvider).deleteEntry(entry.id);
    } on Object catch (e) {
      messenger.showError(describeError(e));
    }
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  Key? actionKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: actionKey ?? const ValueKey('investment-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
