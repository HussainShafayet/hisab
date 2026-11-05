import 'package:flutter/material.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/type_balances.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_type_ui.dart';

/// "Where is my money right now": what each kind of account holds, in a row of
/// small chips (Cash ৳5,000 · bKash ৳1,200 · Bank ৳30,000). The kind of the
/// account being used is marked.
class TypeBalanceStrip extends StatelessWidget {
  const TypeBalanceStrip({
    required this.balances,
    this.highlight = const {},
    super.key,
  });

  final List<TypeBalance> balances;

  /// The kinds of the accounts used by the transaction being written.
  final Set<AccountType> highlight;

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = context.financeColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in balances)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                key: ValueKey('type-balance-${item.type.name}'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(item.type.icon, size: 16, color: item.type.color),
                side: highlight.contains(item.type)
                    ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
                    : null,
                label: Text(
                  '${item.type.label} ${formatPoisha(item.total)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: item.total < 0 ? colors.expense : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
