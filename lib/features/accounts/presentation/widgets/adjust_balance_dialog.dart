import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Asks for the real balance and records an income or expense transaction
/// for the difference. Pops with the [BalanceAdjustment] that was recorded,
/// or with null if cancelled.
class AdjustBalanceDialog extends ConsumerStatefulWidget {
  const AdjustBalanceDialog({required this.item, super.key});

  final AccountWithBalance item;

  @override
  ConsumerState<AdjustBalanceDialog> createState() =>
      _AdjustBalanceDialogState();
}

class _AdjustBalanceDialogState extends ConsumerState<AdjustBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BalanceAdjustment? get _preview {
    final target = parseTakaToPoisha(_controller.text);
    if (target == null) return null;
    return calculateBalanceAdjustment(
      current: widget.item.balance,
      target: target,
    );
  }

  Future<void> _adjust() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final adjustment = await ref
          .read(accountsRepositoryProvider)
          .adjustBalance(
            widget.item.account.id,
            targetBalance: parseTakaToPoisha(_controller.text)!,
          );
      if (mounted) Navigator.of(context).pop(adjustment);
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = parseTakaToPoisha(_controller.text);
    final adjustment = _preview;

    final String? previewText;
    if (target == null) {
      previewText = null;
    } else if (adjustment == null) {
      previewText = 'The balance already matches.';
    } else if (adjustment.type == TransactionType.income) {
      previewText = 'Records ${formatPoisha(adjustment.amount)} as income.';
    } else {
      previewText = 'Records ${formatPoisha(adjustment.amount)} as an expense.';
    }

    return AlertDialog(
      title: const Text('Adjust balance'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.item.account.name} currently shows '
              '${formatPoisha(widget.item.balance)}.',
            ),
            const SizedBox(height: 16),
            MoneyFormField(
              controller: _controller,
              label: 'Actual balance',
              allowNegative: true,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            if (previewText != null) ...[
              const SizedBox(height: 8),
              Text(previewText, style: theme.textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || adjustment == null ? null : _adjust,
          child: const Text('Adjust'),
        ),
      ],
    );
  }
}
