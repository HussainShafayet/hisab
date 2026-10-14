import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';

/// A row of big buttons on Home for the things used most that live under More:
/// Loans (with a red dot when one is late), the bazar list, splitting a bill
/// and savings goals.
class HomeShortcuts extends ConsumerWidget {
  const HomeShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(debtsProvider).value ?? const <DebtItem>[];
    final today = ref.read(clockProvider)();
    final late = debtTotals(items, today).overdueCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _Shortcut(
            key: const ValueKey('shortcut-loans'),
            icon: Icons.handshake_outlined,
            label: tr('Loans'),
            route: AppRoutes.debts,
            alert: late,
          ),
          _Shortcut(
            key: const ValueKey('shortcut-bazar'),
            icon: Icons.shopping_basket_outlined,
            label: tr('Bazar list'),
            route: AppRoutes.bazar,
          ),
          _Shortcut(
            key: const ValueKey('shortcut-split'),
            icon: Icons.call_split,
            label: tr('Split a bill'),
            route: AppRoutes.splitBill,
          ),
          _Shortcut(
            key: const ValueKey('shortcut-goals'),
            icon: Icons.flag_outlined,
            label: tr('Savings goals'),
            route: AppRoutes.goals,
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.route,
    this.alert = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String route;

  /// A red dot on the icon.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (alert)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: DecoratedBox(
                        key: const ValueKey('shortcut-alert'),
                        decoration: BoxDecoration(
                          color: context.financeColors.expense,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 10, height: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
