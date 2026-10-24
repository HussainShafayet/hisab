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
import 'package:hishab/features/tags/domain/tag.dart';
import 'package:hishab/features/tags/presentation/providers/tags_providers.dart';
import 'package:hishab/features/tags/presentation/screens/tags_screen.dart';
import 'package:hishab/features/tags/presentation/widgets/tag_name_dialog.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:hishab/features/settings/presentation/providers/income_privacy_providers.dart';
import 'package:hishab/features/settings/presentation/widgets/hidden_income.dart';

enum _TagAction { rename, delete }

/// One trip or event: what it cost in all, and every transaction in it.
class TagDetailScreen extends ConsumerWidget {
  const TagDetailScreen({required this.tagId, super.key});

  final int tagId;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
    _TagAction action,
  ) async {
    final repository = ref.read(tagsRepositoryProvider);
    switch (action) {
      case _TagAction.rename:
        await showTagNameDialog(
          context,
          title: tr('Rename'),
          initial: tag.name,
          onSave: (name) => repository.renameTag(tag.id, name),
        );
      case _TagAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Delete "{name}"?', {'name': tag.name})),
            content: Text(
              tr(
                'The transactions stay, without this tag. Your accounts and '
                'totals do not change.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr('Cancel')),
              ),
              FilledButton(
                key: const ValueKey('confirm-delete-tag'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(tr('Delete')),
              ),
            ],
          ),
        );
        if (ok == true) {
          await repository.deleteTag(tag.id);
          if (context.mounted) context.pop();
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(tagSummariesProvider);
    final transactions =
        ref.watch(tagTransactionsProvider(tagId)).value ?? const [];
    final theme = Theme.of(context);
    final colors = context.financeColors;

    return summaries.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(tr('Trip or event'))),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(tr('Trip or event'))),
        body: ErrorView(message: describeError(error)),
      ),
      data: (list) {
        final summary = list.where((s) => s.tag.id == tagId).firstOrNull;
        if (summary == null) {
          return Scaffold(
            appBar: AppBar(title: Text(tr('Trip or event'))),
            body: ErrorView(message: tr('This tag no longer exists.')),
          );
        }
        final dates = tagDatesText(summary);
        return Scaffold(
          appBar: AppBar(
            title: Text(summary.tag.name),
            actions: [
              PopupMenuButton<_TagAction>(
                key: const ValueKey('tag-menu'),
                onSelected: (action) =>
                    _onAction(context, ref, summary.tag, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _TagAction.rename,
                    child: Text(tr('Rename')),
                  ),
                  PopupMenuItem(
                    value: _TagAction.delete,
                    child: Text(tr('Delete')),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Spent in all'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatPoisha(summary.expense),
                      key: const ValueKey('tag-expense'),
                      style: theme.textTheme.headlineSmall?.tabular.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.expense,
                      ),
                    ),
                    if (summary.income > 0)
                      ref.watch(incomeHiddenProvider)
                          ? Row(
                              children: [
                                Text(
                                  tr('Received'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.income,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                HiddenIncome(
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.income,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              tr('Received {amount}', {
                                'amount': formatPoisha(summary.income),
                              }),
                              key: const ValueKey('tag-income'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.income,
                              ),
                            ),
                    Text(
                      [
                        plural(
                          summary.count,
                          '1 transaction',
                          '{n} transactions',
                        ),
                        if (dates.isNotEmpty) dates,
                      ].join(' · '),
                      key: const ValueKey('tag-count'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      tr(
                        'Nothing is tagged yet. Choose this tag when you add '
                        'an expense.',
                      ),
                      key: const ValueKey('tag-empty'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final item in transactions)
                  TransactionTile(
                    key: ValueKey('tag-transaction-${item.id}'),
                    item: item,
                    showDate: true,
                    onTap: () =>
                        context.push(AppRoutes.editTransaction(item.id)),
                  ),
            ],
          ),
        );
      },
    );
  }
}
