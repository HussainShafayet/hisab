import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/widgets/debt_actions.dart';
import 'package:hishab/features/debts/presentation/widgets/debt_tile.dart';

/// A loan in a list. Tap opens it, a long press shows quick actions, and an
/// open one can be swiped: right to add a payment, left to mark it all paid
/// (which can be undone).
class LoanListItem extends ConsumerWidget {
  const LoanListItem({
    required this.item,
    required this.today,
    this.showPerson = true,
    super.key,
  });

  final DebtItem item;
  final DateTime today;
  final bool showPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = DebtTile(
      key: ValueKey('debt-${item.debt.id}'),
      item: item,
      today: today,
      showPerson: showPerson,
      onTap: () => context.push(AppRoutes.debt(item.debt.id)),
      onLongPress: () => showLoanActions(context, ref, item),
    );
    if (item.isSettled) return tile;

    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('swipe-${item.debt.id}'),
      background: _SwipeBackground(
        color: scheme.primaryContainer,
        iconColor: scheme.onPrimaryContainer,
        icon: Icons.add,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: scheme.tertiaryContainer,
        iconColor: scheme.onTertiaryContainer,
        icon: Icons.done_all,
        alignment: Alignment.centerRight,
      ),
      // Both swipes do their thing and snap back; the list updates on its own.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await addLoanPayment(context, item);
        } else {
          await markLoanPaid(context, ref, item);
        }
        return false;
      },
      child: tile,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.alignment,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: iconColor),
    );
  }
}
