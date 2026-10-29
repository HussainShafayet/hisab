import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/amount_calculator.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';

/// A calculator in a sheet, for a screen whose amount field is a plain number
/// field (the rows of *Add several*): sums like `1200+350` or `450×3`, with the
/// result under them. Returns the amount as a plain number to put in the field
/// (`1550`), or null when the sheet is closed without using it.
Future<String?> showAmountCalculator(
  BuildContext context, {
  String initial = '',
}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (context) => _AmountCalculatorSheet(initial: initial),
);

class _AmountCalculatorSheet extends StatefulWidget {
  const _AmountCalculatorSheet({required this.initial});

  final String initial;

  @override
  State<_AmountCalculatorSheet> createState() => _AmountCalculatorSheetState();
}

class _AmountCalculatorSheetState extends State<_AmountCalculatorSheet> {
  late String _expression = widget.initial;

  /// The result so far, or null when the sum is not complete or not valid.
  int? get _result => evaluateAmount(_expression);

  void _onKey(String key) =>
      setState(() => _expression = applyKey(_expression, key));

  void _use() {
    final result = _result;
    if (result == null || result <= 0) return;
    Navigator.of(context).pop(poishaToInput(result));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _expression.isEmpty ? '0' : _expression,
                      key: const ValueKey('calc-display'),
                      style: theme.textTheme.headlineMedium?.tabular,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('calc-clear'),
                    onPressed: () => _onKey('C'),
                    child: Text(tr('Clear')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  result == null ? ' ' : '= ${formatPoisha(result)}',
                  key: const ValueKey('calc-result'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            AmountKeypad(onKey: _onKey),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('calc-use'),
                  onPressed: result != null && result > 0 ? _use : null,
                  child: Text(tr('Use this amount')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
