import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/data_check/domain/data_check.dart';
import 'package:hishab/features/data_check/presentation/providers/data_check_providers.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:intl/intl.dart';

/// Looks through the entries for what may be a mistake: an entry made twice,
/// one dated in the future, one far larger than usual, spending in "Other",
/// and categories with almost the same name. Nothing is changed unless the
/// person says so.
class DataCheckScreen extends ConsumerWidget {
  const DataCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(dataCheckProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Data check')),
        actions: const [HelpButton('data-check')],
      ),
      body: check.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: describeError(error),
          onRetry: () => ref.invalidate(dataCheckProvider),
        ),
        data: (data) => data.isClean
            ? EmptyState(
                icon: Icons.verified_outlined,
                title: tr('Everything looks fine'),
                message: tr(
                  'No entry made twice, no date in the future, no amount far '
                  'above the usual, nothing in Other.',
                ),
              )
            : _Findings(data: data),
      ),
    );
  }
}

class _Findings extends ConsumerWidget {
  const _Findings({required this.data});

  final DataCheck data;

  Future<void> _deleteExtras(
    BuildContext context,
    WidgetRef ref,
    DuplicateGroup group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          group.extra == 1
              ? tr('Delete the extra one?')
              : tr('Delete the extra {n}?', {'n': group.extra}),
        ),
        content: Text(
          tr(
            'The first one entered stays. For a few seconds you can undo '
            'this.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-extra'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (sure != true) return;

    final repository = ref.read(transactionsRepositoryProvider);
    try {
      final deleted = await repository.deleteTransactions([
        for (final item in group.items.skip(1)) item.id,
      ]);
      messenger.showMessage(
        tr('{transactions} deleted', {
          'transactions': plural(
            deleted.length,
            '1 transaction',
            '{n} transactions',
          ),
        }),
        duration: undoDuration,
        action: SnackBarAction(
          label: tr('Undo'),
          onPressed: () => repository.restoreTransactions(deleted),
        ),
      );
    } on Object catch (error) {
      messenger.showError(describeError(error));
    }
  }

  Widget _tile(BuildContext context, TransactionItem item) => TransactionTile(
    key: ValueKey('check-item-${item.id}'),
    item: item,
    showDate: true,
    onTap: () => context.push(AppRoutes.editTransaction(item.id)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final other = data.other;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            plural(
              data.findings,
              '1 thing to look at. Nothing is changed unless you say so.',
              '{n} things to look at. Nothing is changed unless you say so.',
            ),
            key: const ValueKey('check-count'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (data.duplicates.isNotEmpty)
          _Section(
            key: const ValueKey('check-duplicates'),
            icon: Icons.content_copy_outlined,
            title: tr('Entered twice?'),
            note: tr(
              'The same day, kind, amount, account and note, from ৳500. '
              'Look, and delete the extra ones if it was a mistake.',
            ),
            children: [
              for (final group in data.duplicates) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    tr('{n} times, {amount}, {date}', {
                      'n': group.items.length,
                      'amount': formatPoisha(group.items.first.amount),
                      'date': DateFormat('d MMM yyyy')
                          .format(group.items.first.date),
                    }),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                for (final item in group.items) _tile(context, item),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextButton.icon(
                      key: ValueKey('delete-extra-${group.items.first.id}'),
                      onPressed: () => _deleteExtras(context, ref, group),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        group.extra == 1
                            ? tr('Delete the extra one')
                            : tr('Delete the extra {n}', {'n': group.extra}),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        if (data.futureDated.isNotEmpty)
          _Section(
            key: const ValueKey('check-future'),
            icon: Icons.event_busy_outlined,
            title: tr('Dated in the future'),
            note: tr(
              'Often a wrong year or a day and month the wrong way round. Open '
              'one to change its date.',
            ),
            children: [
              for (final item in data.futureDated) _tile(context, item),
            ],
          ),
        if (data.unusuallyLarge.isNotEmpty)
          _Section(
            key: const ValueKey('check-large'),
            icon: Icons.trending_up,
            title: tr('Far above the usual'),
            note: tr(
              'At least 10 times the usual amount of its category, and ৳1,000 '
              'or more. A slip of a zero? Open one to look.',
            ),
            children: [
              for (final item in data.unusuallyLarge) _tile(context, item),
            ],
          ),
        if (other != null)
          _Section(
            key: const ValueKey('check-other'),
            icon: Icons.help_outline,
            title: tr('In "Other"'),
            note: tr(
              '{entries} worth {total}. A real category tells you more. Open '
              'one to give it a category, or in Transactions press and hold a '
              'row and choose Select several to move many at once.',
              {
                'entries': plural(other.count, '1 entry', '{n} entries'),
                'total': formatPoisha(other.total),
              },
            ),
            children: [for (final item in other.items) _tile(context, item)],
          ),
        if (data.similarCategories.isNotEmpty)
          _Section(
            key: const ValueKey('check-similar'),
            icon: Icons.call_merge,
            title: tr('Categories that look alike'),
            note: tr(
              'Two names for one thing split the totals. In Categories, open '
              'the menu of one and choose Merge into.',
            ),
            children: [
              for (final pair in data.similarCategories)
                ListTile(
                  key: ValueKey(
                    'check-pair-${pair.first.id}-${pair.second.id}',
                  ),
                  leading: const Icon(Icons.category_outlined),
                  title: Text('${pair.first.name}  ≈  ${pair.second.name}'),
                  onTap: () => context.push(AppRoutes.categories),
                ),
            ],
          ),
      ],
    );
  }
}

/// A group of findings: a heading, what it means, and the rows.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.note,
    required this.children,
    super.key,
  });

  final IconData icon;
  final String title;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
