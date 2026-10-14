import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/overdrawn.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';

/// On Home: the wallets that hold less than nothing, a sign that an entry is
/// missing or wrong. Not shown when every wallet is zero or more.
class OverdrawnCard extends ConsumerWidget {
  const OverdrawnCard({super.key});

  /// How many wallets are listed; the rest are counted in the title.
  static const maxListed = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(accountsProvider(false)).value ?? const [];
    final low = overdrawnAccounts(items);
    if (low.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.financeColors;
    final shown = low.take(maxListed).toList();

    return Card(
      key: const ValueKey('overdrawn-card'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.accounts),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      low.length == 1
                          ? tr('1 account is below zero')
                          : tr('{count} accounts are below zero', {
                              'count': low.length,
                            }),
                      key: const ValueKey('overdrawn-title'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr('A spend or a payment may be missing. Check the entries.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in shown)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // A long amount shrinks to fit a small phone.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatPoisha(item.balance),
                            key: ValueKey('overdrawn-${item.account.id}'),
                            style: theme.textTheme.bodyMedium?.tabular.copyWith(
                              color: colors.expense,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
