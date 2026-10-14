import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/features/fun/presentation/celebrate.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_share.dart';
import 'package:hishab/features/debts/presentation/widgets/payment_dialog.dart';

/// Things to do with one loan, shared by the list, the person screen and the
/// loan screen.

/// Asks for a payment and says so when it was saved.
Future<void> addLoanPayment(BuildContext context, DebtItem item) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => PaymentDialog(item: item),
  );
  if (saved == true) {
    messenger.showMessage(tr('Payment saved.'));
  }
}

/// Pays what is left, today. The message has an Undo that takes it back.
Future<void> markLoanPaid(
  BuildContext context,
  WidgetRef ref,
  DebtItem item,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(debtsRepositoryProvider);
  final now = ref.read(clockProvider)();
  try {
    final paymentId = await repository.addPayment(
      item.debt.id,
      amount: item.remaining,
      paidOn: combineDayWithTime(dateOnly(now), now),
      accountId: item.debt.accountId,
    );
    if (context.mounted) celebrate(context, ref);
    messenger.showMessage(
      tr('All paid.'),
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () => repository.deletePayment(paymentId),
      ),
    );
  } on Object catch (e) {
    messenger.showError(describeError(e));
  }
}

Future<bool> confirmLoanAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
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
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result == true;
}

/// Deletes the loan after asking. True when it was deleted.
Future<bool> deleteLoan(
  BuildContext context,
  WidgetRef ref,
  DebtItem item,
) async {
  final ok = await confirmLoanAction(
    context,
    title: tr('Delete this loan?'),
    body: tr(
      'This removes the loan and its payments. Account balances go back to '
      'how they were.',
    ),
    action: tr('Delete'),
  );
  if (!ok || !context.mounted) return false;
  await ref.read(debtsRepositoryProvider).deleteDebt(item.debt.id);
  return true;
}

/// Sets what a person owes me off against what I owe them, after asking. The
/// message has an Undo.
Future<void> setOffWithPerson(
  BuildContext context,
  WidgetRef ref,
  PersonDebts person,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final amount = person.setOffAmount;
  if (amount <= 0) return;
  final left = person.net.abs();
  final result = person.net > 0
      ? tr('Then {name} will owe you {left}.', {
          'name': person.name,
          'left': formatPoisha(left),
        })
      : (person.net < 0
            ? tr('Then you will owe {name} {left}.', {
                'name': person.name,
                'left': formatPoisha(left),
              })
            : tr('Then you and {name} will be even.', {'name': person.name}));
  final ok = await confirmLoanAction(
    context,
    title: tr('Set off {amount} on both sides?', {
      'amount': formatPoisha(amount),
    }),
    body:
        '${tr('This takes {amount} off both sides. Account balances do not change.', {'amount': formatPoisha(amount)})} $result',
    action: tr('Set off'),
  );
  if (!ok || !context.mounted) return;
  final repository = ref.read(debtsRepositoryProvider);
  try {
    final ids = await repository.setOff(
      person.name,
      on: ref.read(clockProvider)(),
    );
    messenger.showMessage(
      tr('Set off {amount}.', {'amount': formatPoisha(amount)}),
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () => repository.deletePayments(ids),
      ),
    );
  } on Object catch (e) {
    messenger.showError(describeError(e));
  }
}

/// A sheet of quick actions for one loan (a long press on its card).
Future<void> showLoanActions(
  BuildContext context,
  WidgetRef ref,
  DebtItem item,
) {
  final lent = item.debt.direction == DebtDirection.lent;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) {
      Widget action(
        String key,
        IconData icon,
        String label,
        VoidCallback onTap,
      ) => ListTile(
        key: ValueKey(key),
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.of(sheetContext).pop();
          onTap();
        },
      );

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!item.isSettled) ...[
              action(
                'loan-action-payment',
                Icons.add,
                tr('Add a payment'),
                () => addLoanPayment(context, item),
              ),
              action(
                'loan-action-paid',
                Icons.done_all,
                tr('All paid'),
                () => markLoanPaid(context, ref, item),
              ),
              if (lent)
                action(
                  'loan-action-remind',
                  Icons.share_outlined,
                  tr('Send a reminder'),
                  () => shareLoanReminder(
                    context,
                    ref,
                    name: item.debt.person,
                    amount: item.remaining,
                    dueOn: item.debt.dueOn,
                  ),
                ),
            ],
            action(
              'loan-action-edit',
              Icons.edit_outlined,
              tr('Edit'),
              () => context.push(AppRoutes.editDebt(item.debt.id)),
            ),
            action(
              'loan-action-delete',
              Icons.delete_outline,
              tr('Delete'),
              () => deleteLoan(context, ref, item),
            ),
          ],
        ),
      );
    },
  );
}
