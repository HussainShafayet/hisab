import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/tabular_figures.dart';

/// Calculator keypad. Reports the pressed key as a string for `applyKey`:
/// a digit, `.`, an operator (`+ - × ÷`) or `⌫`. Holding `⌫` reports `C`.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({required this.onKey, super.key});

  final ValueChanged<String> onKey;

  static const _layout = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '-'],
    ['.', '0', '⌫', '+'],
  ];

  static bool _isOperator(String key) => '÷×-+'.contains(key);

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleLarge?.tabular;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final row in _layout)
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: SizedBox(
                        height: 48,
                        child: _KeyButton(
                          key: ValueKey('key-$key'),
                          isOperator: _isOperator(key),
                          onPressed: () => onKey(key),
                          onLongPress: key == '⌫' ? () => onKey('C') : null,
                          child: switch (key) {
                            '⌫' => Icon(
                              Icons.backspace_outlined,
                              semanticLabel: tr('Backspace'),
                            ),
                            '-' => Text('−', style: textStyle),
                            _ => Text(key, style: textStyle),
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.isOperator,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    super.key,
  });

  final bool isOperator;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return isOperator
        ? FilledButton.tonal(
            onPressed: onPressed,
            onLongPress: onLongPress,
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            onLongPress: onLongPress,
            child: child,
          );
  }
}
