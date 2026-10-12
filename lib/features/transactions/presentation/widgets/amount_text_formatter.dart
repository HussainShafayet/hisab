import 'package:flutter/services.dart';
import 'package:hishab/features/transactions/domain/amount_calculator.dart';

/// Keeps what is typed in the plain amount field a valid number: digits and
/// one dot, two decimals at most. Bengali digits become 0-9 and a pasted
/// `1,500.50` loses its comma. See [sanitizeAmountText].
class AmountTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = sanitizeAmountText(newValue.text);
    if (clean == newValue.text) return newValue;
    return TextEditingValue(
      text: clean,
      selection: TextSelection.collapsed(offset: clean.length),
    );
  }
}
