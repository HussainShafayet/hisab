import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';

/// What the budget dialog returns: a limit to save (with the category chosen
/// when the dialog offered a choice), or [remove].
class BudgetDialogResult {
  const BudgetDialogResult({
    this.categoryId,
    this.amount,
    this.remove = false,
    this.noCarry,
  });

  final int? categoryId;
  final int? amount;
  final bool remove;

  /// Whether the budget takes nothing from before and passes nothing on, or
  /// null when the dialog did not ask.
  final bool? noCarry;
}

/// A category the budget dialog offers.
typedef BudgetCategoryChoice = ({int id, String label});

/// Asks for a monthly limit. Give [categoryChoices] to also ask which
/// category it is for, and [canRemove] to offer "Remove budget".
class BudgetLimitDialog extends StatefulWidget {
  const BudgetLimitDialog({
    required this.title,
    this.initialAmount,
    this.categoryChoices,
    this.canRemove = false,
    this.showNoCarry = false,
    this.initialNoCarry = false,
    super.key,
  });

  final String title;
  final int? initialAmount;
  final List<BudgetCategoryChoice>? categoryChoices;
  final bool canRemove;

  /// Offers "Do not carry over this budget" (while carrying over is on).
  final bool showNoCarry;
  final bool initialNoCarry;

  @override
  State<BudgetLimitDialog> createState() => _BudgetLimitDialogState();
}

class _BudgetLimitDialogState extends State<BudgetLimitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.initialAmount == null
        ? ''
        : poishaToInput(widget.initialAmount!),
  );
  int? _categoryId;
  late bool _noCarry = widget.initialNoCarry;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseTakaToPoisha(_amount.text)!;
    if (amount <= 0) {
      setState(() => _error = tr('The budget must be above zero.'));
      return;
    }
    Navigator.of(context).pop(
      BudgetDialogResult(
        categoryId: _categoryId,
        amount: amount,
        noCarry: widget.showNoCarry ? _noCarry : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choices = widget.categoryChoices;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (choices != null) ...[
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Category')),
                items: [
                  for (final choice in choices)
                    DropdownMenuItem(
                      value: choice.id,
                      child: Text(choice.label),
                    ),
                ],
                validator: (value) =>
                    value == null ? tr('Choose a category') : null,
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),
            ],
            MoneyFormField(
              controller: _amount,
              label: tr('Monthly limit'),
              autofocus: choices == null,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (widget.showNoCarry)
              CheckboxListTile(
                key: const ValueKey('no-carry'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(tr('Do not carry over this budget')),
                subtitle: Text(
                  tr('It takes nothing from last month and passes nothing on.'),
                ),
                value: _noCarry,
                onChanged: (value) => setState(() => _noCarry = value ?? false),
              ),
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
        if (widget.canRemove)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () =>
                Navigator.of(context)
                    .pop(const BudgetDialogResult(remove: true)),
            child: Text(tr('Remove')),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(tr('Save'))),
      ],
    );
  }
}
